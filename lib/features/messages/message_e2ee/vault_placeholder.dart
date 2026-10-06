import '../data/models/chat_message.dart';

/// True when a body is the vault's own stand-in rather than text it actually
/// opened — an empty ciphertext-only row, a locked vault, or a failed decrypt.
///
/// Anything that re-sends a body has to check it, or the placeholder string
/// itself gets sent as the message: a retry of a failed encrypted send, and a
/// forward, which re-seals the plaintext for every destination.
bool isVaultPlaceholderBody(String body) =>
    body.isEmpty ||
    body == 'Encrypted message' ||
    body == 'Unable to decrypt this message';

/// True when [message] is encrypted and its text has not been opened on this
/// device — what a retry, a forward or a copy must refuse, because the body
/// they would act on is a stand-in.
///
/// An empty body is normally that stand-in. The exception is a message that
/// is nothing but encrypted files (server 0168): its text really is empty,
/// and it is sealed all the same, because the files' keys are sealed under
/// the body's key version. A file whose key opened — or, on a send still
/// pending, one that carries its key — is the proof the vault was open and
/// the empty text is the real one.
bool isUnopenedMessage(ChatMessage message) =>
    message.isEncrypted &&
    isVaultPlaceholderBody(message.body) &&
    !_isOpenedFileMessage(message);

bool _isOpenedFileMessage(ChatMessage message) =>
    message.body.isEmpty &&
    (message.attachments.any((a) => a.secret != null) ||
        message.pendingAttachments.any((a) => a.secret != null));

/// True for the two strings a failed or locked decrypt returns — unlike
/// [isVaultPlaceholderBody], not for an empty one. For a caller that has just
/// run a message through the vault, where empty means "opened, and it has no
/// text" (a message of encrypted files only).
bool isVaultFailureBody(String body) =>
    body.isNotEmpty && isVaultPlaceholderBody(body);
