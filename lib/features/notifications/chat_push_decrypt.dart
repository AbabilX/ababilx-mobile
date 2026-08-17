import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../messages/data/chat_repository.dart';
import '../messages/data/models/chat_message.dart';
import '../messages/message_e2ee/message_vault.dart';
import '../messages/tiptap_plain_text.dart';

/// Body every device shows when it cannot read the message — mirrors the
/// server's placeholder for iOS and for pushes that carry no ciphertext.
const encryptedPushPlaceholder = '🔒 Encrypted message';

/// Decrypts a DM push payload outside the widget tree.
///
/// The server stores only ciphertext, so the phone is the only place the text
/// exists. Android receives encrypted DMs data-only and runs this from the FCM
/// background isolate, where no Riverpod container exists — everything is built
/// from OS secure storage (identity + JWT) instead.
///
/// Returns null whenever anything is missing (no trusted identity, no network,
/// oversized ciphertext left out of the payload): the caller then shows
/// [encryptedPushPlaceholder].
Future<String?> decryptChatPushBody(
  Map<String, dynamic> data, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final encryptedBody = data['enc_body']?.toString() ?? '';
  final nonce = data['enc_nonce']?.toString() ?? '';
  final recipientId = data['recipient_id']?.toString() ?? '';
  final senderId = data['sender_id']?.toString() ?? '';
  final conversationId = data['conversation_id']?.toString() ?? '';
  final keyVersion = int.tryParse(data['enc_key_version']?.toString() ?? '');
  if (encryptedBody.isEmpty ||
      nonce.isEmpty ||
      recipientId.isEmpty ||
      senderId.isEmpty ||
      conversationId.isEmpty ||
      keyVersion == null) {
    return null;
  }

  try {
    return await _decrypt(
      conversationId: conversationId,
      senderId: senderId,
      recipientId: recipientId,
      encryptedBody: encryptedBody,
      nonce: nonce,
      keyVersion: keyVersion,
    ).timeout(timeout);
  } catch (_) {
    return null;
  }
}

Future<String?> _decrypt({
  required String conversationId,
  required String senderId,
  required String recipientId,
  required String encryptedBody,
  required String nonce,
  required int keyVersion,
}) async {
  const storage = SecureStorage(FlutterSecureStorage());
  final vault = MessageVault(ChatRepository(ApiClient(storage)), storage);

  if (!await vault.restoreTrustedIdentityOffline()) return null;

  final message = ChatMessage(
    id: 'push-$conversationId',
    conversationId: conversationId,
    // The message AAD is bound to the sender, the key envelope to the reader.
    userId: senderId,
    body: '',
    createdAt: '',
    encryptedBody: encryptedBody,
    encryptionNonce: nonce,
    encryptionVersion: 1,
    encryptionKeyVersion: keyVersion,
  );

  final decrypted = await vault.decryptMessage(message, recipientId);
  final body = decrypted.body.trim();
  if (body.isEmpty ||
      body == 'Encrypted message' ||
      body == 'Unable to decrypt this message') {
    return null;
  }
  // Bodies are TipTap JSON — a notification wants one line of text.
  final preview = tiptapToPreviewText(body).trim();
  if (preview.isEmpty) return null;
  return preview.length <= 140 ? preview : '${preview.substring(0, 140)}…';
}
