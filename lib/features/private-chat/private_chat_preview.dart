import '../messages/data/models/chat_conversation.dart';

/// [fresh] rows from the server, except that a private DM whose newest
/// message the server already let go (`last_message_private`, server 0160)
/// keeps the preview [previous] drew from this phone's own copy. The server
/// blanks those fields on purpose: what it still holds is an older message.
List<ChatConversation> keepPrivatePreviews(
  List<ChatConversation> fresh,
  List<ChatConversation> previous,
) {
  if (!fresh.any((c) => c.lastMessagePrivate)) return fresh;
  final byId = {for (final c in previous) c.id: c};
  return [
    for (final row in fresh)
      if (!row.lastMessagePrivate || byId[row.id] == null)
        row
      else
        _withPreviewOf(row, byId[row.id]!),
  ];
}

ChatConversation _withPreviewOf(ChatConversation row, ChatConversation old) =>
    row.copyWith(
      lastMessageBody: old.lastMessageBody ?? '',
      lastMessageUserId: old.lastMessageUserId ?? '',
      lastMessageAttachmentType: old.lastMessageAttachmentType,
      lastMessageAttachmentName: old.lastMessageAttachmentName,
      lastMessageAttachments: old.lastMessageAttachments,
      lastMessageEncryptedBody: old.lastMessageEncryptedBody,
      lastMessageEncryptionNonce: old.lastMessageEncryptionNonce,
      lastMessageEncryptionVersion: old.lastMessageEncryptionVersion,
      lastMessageEncryptionKeyVersion: old.lastMessageEncryptionKeyVersion,
    );
