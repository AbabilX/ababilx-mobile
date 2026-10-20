import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/chat_repository.dart';
import '../../messages/data/local/chat_message_store.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/message_e2ee/vault_placeholder.dart';
import '../../messages/providers/chat_provider.dart';
import '../../messages/tiptap_plain_text.dart';

/// One line on a Catch up card: who said it, and a one-line preview.
class CatchUpLine {
  const CatchUpLine({required this.name, required this.text, required this.mine});

  final String name;
  final String text;
  final bool mine;
}

/// Newest main-timeline messages, oldest of that window first (so the
/// card reads top → bottom like a chat). Disk first — the phone is the
/// archive — then the server page when the chat was never opened.
final catchUpMessagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, conversationId) async {
      final store = ref.watch(chatMessageStoreProvider);
      var messages = await store.page(conversationId, limit: 5);
      if (messages.isEmpty) {
        try {
          final page = await ref
              .read(chatRepositoryProvider)
              .listMessages(conversationId, limit: 5);
          messages = page.messages;
        } catch (_) {}
      }
      messages = [for (final m in messages) if (!m.isDeleted) m];
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (messages.length > 5) {
        messages = messages.sublist(messages.length - 5);
      }
      final me = ref.read(chatProvider).currentUserId;
      if (me.isNotEmpty && messages.any((m) => m.isEncrypted)) {
        try {
          messages = await ref
              .read(messageVaultProvider)
              .decryptMessages(messages, me);
        } catch (_) {}
      }
      return messages;
    });

/// Plain one-line text for a stored message. Encrypted rows that did not
/// open stay as "Encrypted message" rather than ciphertext.
CatchUpLine catchUpLine(ChatMessage message, String currentUserId) {
  final mine = currentUserId.isNotEmpty && message.userId == currentUserId;
  final name = mine ? '' : (message.userName?.trim() ?? '');
  return CatchUpLine(name: name, text: _lineText(message), mine: mine);
}

String _lineText(ChatMessage message) {
  if (message.contentPurged) return 'Message kept on your phone';
  if (message.isVoiceCall) return 'Voice call';
  if (message.isGroupCall) return 'Group call';
  final body = tiptapToPreviewText(message.body).trim();
  if (body.isNotEmpty && !isVaultPlaceholderBody(body)) return body;
  if (message.attachments.isNotEmpty) {
    final file = message.attachments.first;
    if (file.contentType.toLowerCase().startsWith('image/')) return 'Photo';
    if (file.contentType.toLowerCase().startsWith('video/')) return 'Video';
    if (file.contentType.toLowerCase().startsWith('audio/')) return 'Voice message';
    final name = file.fileName.trim();
    return name.isEmpty ? 'Attachment' : name;
  }
  if (message.isEncrypted || isVaultPlaceholderBody(body)) {
    return 'Encrypted message';
  }
  return body.isEmpty ? 'Message' : body;
}
