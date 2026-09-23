import '../../tiptap_plain_text.dart';
import '../models/chat_message.dart';
import 'chat_message_row.dart';
import 'chat_message_store.dart';

typedef LocalMessageDecryptor =
    Future<List<ChatMessage>> Function(List<ChatMessage> messages);

/// Searches downloaded plaintext rows plus vault-decrypted DMs in memory.
class LocalMessageSearch {
  const LocalMessageSearch(this._store, this._decrypt);

  final ChatMessageStore _store;
  final LocalMessageDecryptor _decrypt;

  /// [conversationId] narrows to one chat — a chat's own search must not
  /// have its hits crowded out by the newest 30 across every other chat.
  Future<List<ChatMessage>> search(
    String query, {
    int limit = 30,
    String? conversationId,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final found = <String, ChatMessage>{};
    for (final message in await _store.search(
      q,
      limit: limit,
      conversationId: conversationId,
    )) {
      found[message.id] = message;
    }

    const pageSize = 200;
    var offset = 0;
    var encryptedMatches = 0;
    while (encryptedMatches < limit) {
      final encrypted = await _store.encryptedPage(
        limit: pageSize,
        offset: offset,
        conversationId: conversationId,
      );
      if (encrypted.isEmpty) break;
      final decrypted = await _decrypt(encrypted);
      for (final message in decrypted) {
        if (_matches(message, q) && !found.containsKey(message.id)) {
          found[message.id] = message;
          encryptedMatches++;
        }
      }
      if (encrypted.length < pageSize) break;
      offset += encrypted.length;
    }

    final results = found.values.toList()
      ..sort((a, b) => messageTimeMs(b).compareTo(messageTimeMs(a)));
    return results.take(limit).toList();
  }
}

bool _matches(ChatMessage message, String query) {
  if (message.isDeleted) return false;
  final text = tiptapToPreviewText(message.body).toLowerCase();
  final names = message.attachments
      .map((attachment) => attachment.fileName.toLowerCase())
      .join(' ');
  return text.contains(query) || names.contains(query);
}
