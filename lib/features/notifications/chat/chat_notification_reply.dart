import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../messages/data/chat_client_message_id.dart';
import '../../messages/data/chat_repository.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/tiptap_plain_text.dart';

/// Sends a reply typed into the notification shade, without opening the app.
///
/// Runs in whichever isolate handled the notification action, so it builds its
/// own repository from OS secure storage instead of reading Riverpod. An
/// encrypted DM is sealed here exactly as the composer seals it — the server
/// never sees the plaintext, notification reply or not.
///
/// [parentId] sends it as a thread reply under that message.
///
/// Returns false when the reply could not be sent; the caller then tells the
/// user rather than silently dropping what they typed.
Future<bool> sendChatNotificationReply(
  Map<String, dynamic> data,
  String text, {
  String? parentId,
}) async {
  final conversationId = data['conversation_id']?.toString() ?? '';
  final trimmed = text.trim();
  if (conversationId.isEmpty || trimmed.isEmpty) return false;

  try {
    const raw = FlutterSecureStorage();
    const storage = SecureStorage(raw);
    final token = await storage.readJwt();
    if (token == null || token.isEmpty) return false;

    final repo = ChatRepository(ApiClient(storage));
    final body = textToTiptapJson(trimmed);
    final sealed = await _seal(repo, storage, data, body);

    await repo.sendMessage(
      conversationId,
      clientMessageId: newChatClientMessageId(),
      body: sealed == null ? body : '',
      encryptedBody: sealed?.encryptedBody,
      encryptionNonce: sealed?.nonce,
      encryptionVersion: sealed == null ? null : 1,
      encryptionKeyVersion: sealed?.keyVersion,
      parentId: parentId,
    );
    // Replying is reading: leaving the conversation unread after it would put
    // the badge back the moment the app opens.
    await _ignoreFailure(repo.markRead(conversationId));
    return true;
  } catch (_) {
    return false;
  }
}

/// Marks the conversation read from the notification's own button.
Future<bool> markChatNotificationRead(String conversationId) async {
  if (conversationId.isEmpty) return false;
  try {
    const storage = SecureStorage(FlutterSecureStorage());
    final token = await storage.readJwt();
    if (token == null || token.isEmpty) return false;
    await ChatRepository(ApiClient(storage)).markRead(conversationId);
    return true;
  } catch (_) {
    return false;
  }
}

/// Seals [body] for an encrypted conversation, or returns null for one that is
/// sent in plaintext (workspace channels).
///
/// `recipient_id` is this device's own user id — the push named it so the key
/// envelope could be opened — and it is what the vault seals as. The server
/// writes it only into an encrypted push, so its presence IS the discriminator;
/// testing the type for "chat_dm" instead is what made a personal group's
/// shade-reply go out in plaintext to a conversation that refuses plaintext.
Future<EncryptedDmPayload?> _seal(
  ChatRepository repo,
  SecureStorage storage,
  Map<String, dynamic> data,
  String body,
) async {
  final myUserId = data['recipient_id']?.toString() ?? '';
  final conversationId = data['conversation_id']?.toString() ?? '';
  if (myUserId.isEmpty || conversationId.isEmpty) return null;

  final vault = MessageVault(repo, storage);
  if (!await vault.restoreTrustedIdentityOffline()) {
    // No trusted identity on this device: sending plaintext would leak the
    // message, so the reply fails and the user is told.
    throw StateError('chat vault locked');
  }
  // encryptNew, not encryptExisting: a key somebody in the conversation can no
  // longer read is rotated here rather than producing a reply nobody can open.
  // The roster comes from the server, so this works for a group reply too — the
  // push no longer has to name a peer for it.
  return vault.encryptNew(
    conversationId: conversationId,
    text: body,
    currentUserId: myUserId,
  );
}

Future<void> _ignoreFailure(Future<void> future) async {
  try {
    await future;
  } catch (_) {}
}
