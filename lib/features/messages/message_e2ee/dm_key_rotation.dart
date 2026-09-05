import '../../../core/network/friendly_error.dart';
import 'message_vault.dart';

/// The refusals that mean the conversation key a message was sealed with is
/// unreadable to somebody in the conversation. In practice the other side
/// started a fresh identity: that drops their key envelope while this device's
/// own envelope stays valid, so nothing looks wrong locally and the send would
/// otherwise succeed into a message they could never open.
bool isStaleChatKeyError(Object error) {
  final code = serverErrorCode(error);
  return code == 'chat_key_rotation_required' ||
      code == 'message encryption key unavailable';
}

/// Encrypts a DM and hands it to [send], re-keying once if the server refuses.
///
/// Exactly one retry: a second refusal is a real problem and belongs in front
/// of the user rather than in a loop.
Future<T> sendEncryptedDm<T>({
  required MessageVault vault,
  required String conversationId,
  required String text,
  required String currentUserId,
  required String peerUserId,
  required Future<T> Function(EncryptedDmPayload) send,
}) async {
  try {
    return await send(
      await vault.encryptNew(
        conversationId: conversationId,
        text: text,
        currentUserId: currentUserId,
        peerUserId: peerUserId,
      ),
    );
  } catch (error) {
    if (!isStaleChatKeyError(error)) rethrow;
    return send(
      await vault.rekeyAndEncrypt(
        conversationId: conversationId,
        text: text,
        currentUserId: currentUserId,
        peerUserId: peerUserId,
      ),
    );
  }
}
