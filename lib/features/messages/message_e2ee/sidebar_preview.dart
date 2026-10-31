import '../data/models/chat_models.dart';
import 'vault_placeholder.dart';

// Chat-list previews of sealed conversations — a DM and a personal group
// alike. Web and desktop keep the same rule in `lib/chat-e2ee/sidebar-preview.ts`.
//
// The server cannot read a sealed message, so a sidebar row carries the last
// message's ciphertext beside a placeholder body and the device opens it.
// The reference app gets the same result by storing the decrypted snippet in
// its encrypted database; we keep ciphertext at rest, so the text lives in
// memory only and [previewForDisk] puts the placeholder back before a row is
// written — the rule the message store already follows.

/// Whether [row]'s last message is ciphertext this device might open.
bool hasSealedPreview(ChatConversation row) =>
    row.lastMessageEncryptionVersion == 1 &&
    (row.lastMessageEncryptedBody ?? '').isNotEmpty &&
    (row.lastMessageEncryptionNonce ?? '').isNotEmpty &&
    (row.lastMessageUserId ?? '').isNotEmpty;

/// The stand-in message a preview is opened as. The author matters: the
/// cipher binds the sender id into its AAD.
ChatMessage sealedPreviewMessage(ChatConversation row) => ChatMessage(
  id: 'sidebar-${row.id}',
  conversationId: row.id,
  userId: row.lastMessageUserId ?? '',
  body: '',
  createdAt: row.lastMessageAt ?? '',
  encryptedBody: row.lastMessageEncryptedBody,
  encryptionNonce: row.lastMessageEncryptionNonce,
  encryptionVersion: row.lastMessageEncryptionVersion,
  encryptionKeyVersion: row.lastMessageEncryptionKeyVersion,
);

/// Whether text opened from [opened]'s ciphertext may still be written onto
/// [current].
///
/// A decrypt is async and the row moves under it — a websocket message, a
/// sidebar refresh — so an older message must never land on a newer one, and
/// text already on screen is never replaced.
bool previewStillCurrent(ChatConversation current, ChatConversation opened) =>
    current.lastMessageEncryptedBody == opened.lastMessageEncryptedBody &&
    current.lastMessageEncryptionNonce == opened.lastMessageEncryptionNonce &&
    isVaultPlaceholderBody(current.lastMessageBody ?? '');

/// The row as it may be written to disk: sealed text goes back to the
/// placeholder, the ciphertext beside it stays so the next launch can reopen it.
ChatConversation previewForDisk(ChatConversation row) =>
    row.lastMessageEncryptionVersion == 1
    ? row.copyWith(lastMessageBody: 'Encrypted message')
    : row;

/// The row after [message] became its newest. The ciphertext columns have to
/// follow the message, or the next preview pass reopens the PREVIOUS one.
ChatConversation withLastMessageCipher(
  ChatConversation row,
  ChatMessage message,
) => message.isEncrypted
    ? row.copyWith(
        lastMessageEncryptedBody: message.encryptedBody,
        lastMessageEncryptionNonce: message.encryptionNonce,
        lastMessageEncryptionVersion: message.encryptionVersion,
        lastMessageEncryptionKeyVersion: message.encryptionKeyVersion,
        // This message is here whole, whatever the last one was.
        lastMessageLong: false,
      )
    : row.copyWith(clearLastMessageEncryption: true);
