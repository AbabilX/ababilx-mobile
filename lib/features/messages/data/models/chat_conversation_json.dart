import 'chat_conversation.dart';

extension ChatConversationJson on ChatConversation {
  Map<String, dynamic> toJson() => {
        'id': id,
        'team_id': teamId,
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
        'last_message_attachments':
            lastMessageAttachments.map((a) => a.toJson()).toList(),
        'peer_user_id': peerUserId,
        'peer_user_name': peerUserName,
        'peer_user_avatar': peerUserAvatar,
        'peer_left': peerLeft,
        'muted': muted,
        'member_avatars': memberAvatars,
        'member_count': memberCount,
      };
}
