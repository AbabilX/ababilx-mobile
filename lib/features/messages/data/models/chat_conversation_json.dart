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
    if (lastMessageLong) 'last_message_long': true,
    'peer_user_id': peerUserId,
    'peer_user_name': peerUserName,
    'peer_user_avatar': peerUserAvatar,
    'peer_user_cover': peerUserCover,
    if (peerShareHandle.isNotEmpty) 'peer_share_handle': peerShareHandle,
    if (peerShareEmail.isNotEmpty) 'peer_share_email': peerShareEmail,
    if (peerSharePhone.isNotEmpty) 'peer_share_phone': peerSharePhone,
    'peer_user_email': peerUserEmail,
    // A group's own picture and identity. Left out, every cold start drew the
    // member montage (or the bare icon) until the network answered.
    'avatar_url': avatarUrl,
    'banner_url': bannerUrl,
    'description': description,
    'edit_info_role': editInfoRole,
    'add_members_role': addMembersRole,
    'my_role': myRole,
    'peer_left': peerLeft,
    'is_self': isSelf,
    'peer_privacy': peerPrivacy,
    'receipts_hidden': receiptsHidden,
    'my_receipts_hidden': myReceiptsHidden,
    'private_chat': privateChat,
    'private_chat_by': privateChatBy,
    'last_message_private': lastMessagePrivate,
    'can_message': canMessage,
    'lock_reason': lockReason,
    'plaintext_until_keyed': plaintextUntilKeyed,
    'request_state': requestState,
    'muted': muted,
    'muted_until': mutedUntil?.toUtc().toIso8601String(),
    'mute_mode': muteMode,
    'pinned': pinned,
    'member_avatars': memberAvatars,
    'member_count': memberCount,
    // Kept on disk so an offline cold start never opens a private group
    // unlocked.
    'group_privacy': groupPrivacy,
    'public_link': publicLink,
    'public_link_paused': publicLinkPaused,
    // Same reason: a member an admin made read-only must not find the
    // composer open on an offline cold start.
    'my_permissions': myPermissions?.toJson(),
    'default_permissions': defaultPermissions?.toJson(),
  };
}
