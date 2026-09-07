import '../data/models/chat_conversation.dart';
import '../message_e2ee/message_vault.dart';

/// Builds the per-destination payloads a forward needs.
///
/// The server cannot do this itself. It never holds the plaintext of an
/// encrypted message, and every conversation is sealed under its own key, so
/// each destination needs its own ciphertext. Workspace channels stay
/// plaintext — the server copies its own stored body there, so [text] only
/// matters when the source or the destination is encrypted.
///
/// Mirrors web's `buildForwardTargets`; both feed the same handler, and the
/// encrypted/plaintext split has to agree with the server's `e2eeEligible` or
/// a destination answers 400 on one side and 409 on the other.
Future<List<Map<String, dynamic>>> buildForwardTargets({
  required MessageVault vault,
  required String currentUserId,
  required String text,
  required List<ChatConversation> conversations,
  String caption = '',
}) async {
  final targets = <Map<String, dynamic>>[];
  for (final conversation in conversations) {
    targets.add(
      conversation.isEncrypted
          ? await _encryptedTarget(
              vault: vault,
              conversationId: conversation.id,
              currentUserId: currentUserId,
              text: text,
              caption: caption,
            )
          : {
              'conversation_id': conversation.id,
              'message': {'body': text},
              if (caption.isNotEmpty) 'caption': {'body': caption},
            },
    );
  }
  return targets;
}

Future<Map<String, dynamic>> _encryptedTarget({
  required MessageVault vault,
  required String conversationId,
  required String currentUserId,
  required String text,
  required String caption,
}) async {
  Future<Map<String, dynamic>> seal(String value) async {
    final payload = await vault.encryptNew(
      conversationId: conversationId,
      text: value,
      currentUserId: currentUserId,
    );
    return {
      'encrypted_body': payload.encryptedBody,
      'encryption_nonce': payload.nonce,
      'encryption_key_version': payload.keyVersion,
    };
  }

  return {
    'conversation_id': conversationId,
    // An attachment-only forward has nothing to encrypt, and the server
    // accepts an empty payload when attachments travel with it.
    'message': text.trim().isEmpty ? <String, dynamic>{} : await seal(text),
    if (caption.isNotEmpty) 'caption': await seal(caption),
  };
}
