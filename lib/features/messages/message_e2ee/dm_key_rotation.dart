import '../../../core/network/friendly_error.dart';
import 'message_vault.dart';

/// The refusals that mean the conversation key a message was sealed with is
/// unreadable to somebody in the conversation: they started a fresh identity
/// (which drops their envelope while this device's stays valid, so nothing
/// looks wrong locally), they joined after the key was minted, or somebody was
/// removed and the key was retired. Without the retry the send would succeed
/// into a message they could never open — or one a departed member still can.
bool isStaleChatKeyError(Object error) {
  final code = serverErrorCode(error);
  return code == 'chat_key_rotation_required' ||
      code == 'message encryption key unavailable';
}

/// Encrypts a message and hands it to [send], re-keying once if the server
/// refuses. Used by DMs and personal groups alike — the roster is the server's
/// business, not this function's.
///
/// Exactly one retry: a second refusal is a real problem and belongs in front
/// of the user rather than in a loop.
///
/// [sendUnencrypted] is passed only for a group the server marks
/// `plaintext_until_keyed`: a converted workspace channel that has never had a
/// key, with somebody in it who cannot be sealed to yet ([ChatKeyNotReady]).
/// It has been plaintext all its life, so sending as it is downgrades nothing,
/// and the first send after they set up secure messages mints the key. Every
/// other conversation passes none and fails instead.
Future<T> sendEncryptedChat<T>({
  required MessageVault vault,
  required String conversationId,
  required String text,
  required String currentUserId,
  required Future<T> Function(EncryptedDmPayload) send,
  Future<T> Function()? sendUnencrypted,
}) async {
  try {
    return await send(
      await vault.encryptNew(
        conversationId: conversationId,
        text: text,
        currentUserId: currentUserId,
      ),
    );
  } on ChatKeyNotReady {
    if (sendUnencrypted == null) rethrow;
    return sendUnencrypted();
  } catch (error) {
    if (!isStaleChatKeyError(error)) rethrow;
    return send(
      await vault.rekeyAndEncrypt(
        conversationId: conversationId,
        text: text,
        currentUserId: currentUserId,
      ),
    );
  }
}
