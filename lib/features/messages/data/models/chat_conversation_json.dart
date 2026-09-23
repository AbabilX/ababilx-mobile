import 'chat_conversation.dart';

extension ChatConversationJson on ChatConversation {
  Map<String, dynamic> toJson() => {
    'id': id,
    'team_id': teamId,
    'scope': scope,
    'type': type,
    'name': name,
    'slug': slug,
    'is_private': isPrivate,
    'created_by': createdBy,
    'created_at': createdAt,
    'archived_at': archivedAt,
    'unread_count': unreadCount,
    'last_message_at': lastMessageAt,
    'last_message_body': lastMessageBody,
    'last_message_user_id': lastMessageUserId,
    'last_message_attachment_type': lastMessageAttachmentType,
    'last_message_attachment_name': lastMessageAttachmentName,
    'last_message_attachments': lastMessageAttachments
        .map((a) => a.toJson())
        .toList(),
    'last_message_encrypted_body': lastMessageEncryptedBody,
    'last_message_encryption_nonce': lastMessageEncryptionNonce,
    'last_message_encryption_version': lastMessageEncryptionVersion,
    'last_message_encryption_key_version': lastMessageEncryptionKeyVersion,
    'peer_user_id': peerUserId,
    'peer_user_name': peerUserName,
    'peer_user_avatar': peerUserAvatar,
    'peer_user_cover': peerUserCover,
    'peer_left': peerLeft,
    'is_self': isSelf,
    'peer_privacy': peerPrivacy,
    'can_message': canMessage,
    'lock_reason': lockReason,
    'plaintext_until_keyed': plaintextUntilKeyed,
    'request_state': requestState,
    'muted': muted,
    'pinned': pinned,
    'member_avatars': memberAvatars,
    'member_count': memberCount,
  };
}
