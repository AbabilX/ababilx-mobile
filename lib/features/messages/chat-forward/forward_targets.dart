import '../../attachments/crypto/attachment_secret.dart';
import '../data/models/chat_attachment.dart';
import '../data/models/chat_conversation.dart';
import '../message_e2ee/encryption_pins.dart';
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
///
/// [attachments] are the forwarded message's files. The server copies their
/// rows and points them at the same objects, but an encrypted file's key
/// (server 0168) is sealed under its own conversation's key, so each
/// destination gets that key sealed again under ITS key. A destination that
/// takes no ciphertext cannot receive one, and neither can a file whose key
/// never opened on this phone — both refuse here, in words, rather than
/// arrive as a file nobody can open.
Future<List<Map<String, dynamic>>> buildForwardTargets({
  required MessageVault vault,
  required String currentUserId,
  required String text,
  required List<ChatConversation> conversations,
  List<ChatMessageAttachment> attachments = const [],
  String caption = '',
  Set<String> pinned = const {},
}) async {
  if (attachments.any((a) => a.needsKey)) {
    throw StateError('This file cannot be forwarded from this phone yet');
  }
  final files = [
    for (final a in attachments)
      if (a.secret != null)
        ChatAttachmentInput(
          fileUrl: a.fileUrl,
          fileName: a.fileName,
          contentType: a.contentType,
          sizeBytes: a.sizeBytes,
          secret: a.secret,
        ),
  ];
  final targets = <Map<String, dynamic>>[];
  for (final conversation in conversations) {
    Map<String, dynamic>? sealed;
    // [pinned]: chats this phone has known as encrypted. They are sealed to
    // even when the list no longer calls them encrypted, and never fall back.
    final isPinned = pinned.contains(conversation.id);
    if (mustSealChat(pinned: isPinned, conversation: conversation)) {
      try {
        sealed = await _encryptedTarget(
          vault: vault,
          conversationId: conversation.id,
          currentUserId: currentUserId,
          text: text,
          caption: caption,
          files: files,
        );
      } on ChatKeyNotReady {
        // The same rule as an ordinary send: only a group the server marks
        // plaintext_until_keyed may take the text as it is. Anything else —
        // a DM, a group created as a group — refuses.
        if (!mayStayPlaintext(pinned: isPinned, conversation: conversation)) {
          rethrow;
        }
      }
    }
    if (sealed == null && files.isNotEmpty) {
      throw StateError('Encrypted files can only be forwarded to secure chats');
    }
    targets.add(
      sealed ??
          {
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
  required List<ChatAttachmentInput> files,
}) async {
  var keyVersion = 0;
  Future<Map<String, dynamic>> seal(String value) async {
    final payload = await vault.encryptNew(
      conversationId: conversationId,
      text: value,
      currentUserId: currentUserId,
    );
    keyVersion = payload.keyVersion;
    return {
      'encrypted_body': payload.encryptedBody,
      'encryption_nonce': payload.nonce,
      'encryption_key_version': payload.keyVersion,
    };
  }

  // An attachment-only forward has nothing to encrypt, and the server accepts
  // an empty payload when plaintext attachments travel with it. Encrypted
  // files are different: their keys are sealed under the body's key version,
  // so the message is sealed even when its text is empty.
  final message = text.trim().isEmpty && files.isEmpty
      ? <String, dynamic>{}
      : await seal(text);
  final seals = files.isEmpty
      ? const <String, SealedAttachmentMeta>{}
      : await vault.sealAttachments(
          conversationId: conversationId,
          currentUserId: currentUserId,
          keyVersion: keyVersion,
          attachments: files,
        );
  return {
    'conversation_id': conversationId,
    'message': message,
    if (seals.isNotEmpty)
      'attachments': [
        for (final entry in seals.entries)
          {
            'file_url': entry.key,
            'enc_meta': entry.value.encMeta,
            'enc_nonce': entry.value.encNonce,
          },
      ],
    if (caption.isNotEmpty) 'caption': await seal(caption),
  };
}
