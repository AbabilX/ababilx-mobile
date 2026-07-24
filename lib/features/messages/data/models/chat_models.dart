import 'package:equatable/equatable.dart';

class ChatReactionUser extends Equatable {
  const ChatReactionUser({required this.userId, this.name, this.avatarUrl});

  final String userId;
  final String? name;
  final String? avatarUrl;

  factory ChatReactionUser.fromJson(Map<String, dynamic> json) =>
      ChatReactionUser(
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  @override
  List<Object?> get props => [userId];
}

class ChatReactionGroup extends Equatable {
  const ChatReactionGroup({
    required this.emoji,
    required this.count,
    this.users = const [],
    this.reactedByMe = false,
  });

  final String emoji;
  final int count;
  final List<ChatReactionUser> users;
  final bool reactedByMe;

  factory ChatReactionGroup.fromJson(Map<String, dynamic> json) =>
      ChatReactionGroup(
        emoji: json['emoji'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        users: (json['users'] as List<dynamic>? ?? [])
            .map((e) => ChatReactionUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactedByMe: json['reacted_by_me'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [emoji, count, reactedByMe];
}

class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.teamId,
    required this.type,
    this.name,
    this.slug,
    this.isPrivate = false,
    this.createdBy,
    required this.createdAt,
    this.archivedAt,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.lastMessageBody,
    this.lastMessageUserId,
    this.lastMessageAttachmentType,
    this.lastMessageAttachmentName,
    this.peerUserId,
    this.peerUserName,
    this.peerUserAvatar,
    this.peerLeft = false,
    this.muted = false,
    this.memberAvatars = const [],
    this.memberCount,
  });

  final String id;
  final String teamId;
  final String type; // channel | dm
  final String? name;
  final String? slug;
  final bool isPrivate;
  final String? createdBy;
  final String createdAt;
  final String? archivedAt;
  final int unreadCount;
  final String? lastMessageAt;
  final String? lastMessageBody;
  final String? lastMessageUserId;
  final String? lastMessageAttachmentType;
  final String? lastMessageAttachmentName;
  final String? peerUserId;
  final String? peerUserName;
  final String? peerUserAvatar;
  final bool peerLeft;
  final bool muted;
  final List<String> memberAvatars;
  final int? memberCount;

  bool get isChannel => type == 'channel';
  bool get isDm => type == 'dm';

  String displayTitle(String? currentUserId) {
    if (isChannel) return name ?? slug ?? 'Channel';
    return peerUserName ?? 'Direct message';
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id'] as String? ?? '',
        teamId: json['team_id'] as String? ?? '',
        type: json['type'] as String? ?? 'channel',
        name: json['name'] as String?,
        slug: json['slug'] as String?,
        isPrivate: json['is_private'] as bool? ?? false,
        createdBy: json['created_by'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        archivedAt: json['archived_at'] as String?,
        unreadCount: json['unread_count'] as int? ?? 0,
        lastMessageAt: json['last_message_at'] as String?,
        lastMessageBody: json['last_message_body'] as String?,
        lastMessageUserId: json['last_message_user_id'] as String?,
        lastMessageAttachmentType:
            json['last_message_attachment_type'] as String?,
        lastMessageAttachmentName:
            json['last_message_attachment_name'] as String?,
        peerUserId: json['peer_user_id'] as String?,
        peerUserName: json['peer_user_name'] as String?,
        peerUserAvatar: json['peer_user_avatar'] as String?,
        peerLeft: json['peer_left'] as bool? ?? false,
        muted: json['muted'] as bool? ?? false,
        memberAvatars: (json['member_avatars'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        memberCount: json['member_count'] as int?,
      );

  ChatConversation copyWith({
    int? unreadCount,
    String? lastMessageAt,
    String? lastMessageBody,
    String? lastMessageUserId,
    String? lastMessageAttachmentType,
    String? lastMessageAttachmentName,
    bool? muted,
    String? name,
  }) =>
      ChatConversation(
        id: id,
        teamId: teamId,
        type: type,
        name: name ?? this.name,
        slug: slug,
        isPrivate: isPrivate,
        createdBy: createdBy,
        createdAt: createdAt,
        archivedAt: archivedAt,
        unreadCount: unreadCount ?? this.unreadCount,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessageBody: lastMessageBody ?? this.lastMessageBody,
        lastMessageUserId: lastMessageUserId ?? this.lastMessageUserId,
        lastMessageAttachmentType:
            lastMessageAttachmentType ?? this.lastMessageAttachmentType,
        lastMessageAttachmentName:
            lastMessageAttachmentName ?? this.lastMessageAttachmentName,
        peerUserId: peerUserId,
        peerUserName: peerUserName,
        peerUserAvatar: peerUserAvatar,
        peerLeft: peerLeft,
        muted: muted ?? this.muted,
        memberAvatars: memberAvatars,
        memberCount: memberCount,
      );

  @override
  List<Object?> get props => [id, unreadCount, lastMessageAt, muted, name];
}

class ChatMember extends Equatable {
  const ChatMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.joinedAt,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String joinedAt;

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        joinedAt: json['joined_at'] as String? ?? '',
      );

  @override
  List<Object?> get props => [userId];
}

class ChatMessageAttachment extends Equatable {
  const ChatMessageAttachment({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String fileName;
  final String fileUrl;
  final String contentType;
  final int sizeBytes;
  final String uploadedBy;
  final String createdAt;

  factory ChatMessageAttachment.fromJson(Map<String, dynamic> json) =>
      ChatMessageAttachment(
        id: json['id'] as String? ?? '',
        messageId: json['message_id'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        fileUrl: json['file_url'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        uploadedBy: json['uploaded_by'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, fileUrl];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.body,
    this.parentId,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.userName,
    this.userAvatarUrl,
    this.attachments = const [],
    this.reactions = const [],
    this.threadCount = 0,
    this.viaAbabilx = false,
    this.messageType = 'text',
    this.forwardedFromName,
    this.forwardedFromSource,
  });

  final String id;
  final String conversationId;
  final String userId;
  final String body;
  final String? parentId;
  final String createdAt;
  final String? editedAt;
  final String? deletedAt;
  final String? userName;
  final String? userAvatarUrl;
  final List<ChatMessageAttachment> attachments;
  final List<ChatReactionGroup> reactions;
  final int threadCount;
  final bool viaAbabilx;
  final String messageType;
  final String? forwardedFromName;
  final String? forwardedFromSource;

  bool get isDeleted => deletedAt != null;
  bool get isSystem => messageType == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        conversationId: json['conversation_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        parentId: json['parent_id'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        editedAt: json['edited_at'] as String?,
        deletedAt: json['deleted_at'] as String?,
        userName: json['user_name'] as String?,
        userAvatarUrl: json['user_avatar_url'] as String?,
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((e) =>
                ChatMessageAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactions: (json['reactions'] as List<dynamic>? ?? [])
            .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        threadCount: json['thread_count'] as int? ?? 0,
        viaAbabilx: json['via_ababilx'] as bool? ?? false,
        messageType: json['message_type'] as String? ?? 'text',
        forwardedFromName: json['forwarded_from_name'] as String?,
        forwardedFromSource: json['forwarded_from_source'] as String?,
      );

  ChatMessage copyWith({
    String? body,
    String? editedAt,
    String? deletedAt,
    List<ChatReactionGroup>? reactions,
    int? threadCount,
  }) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        userId: userId,
        body: body ?? this.body,
        parentId: parentId,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        attachments: attachments,
        reactions: reactions ?? this.reactions,
        threadCount: threadCount ?? this.threadCount,
        viaAbabilx: viaAbabilx,
        messageType: messageType,
        forwardedFromName: forwardedFromName,
        forwardedFromSource: forwardedFromSource,
      );

  @override
  List<Object?> get props => [id, body, editedAt, deletedAt, reactions, threadCount];
}

class ChatMessagesPage extends Equatable {
  const ChatMessagesPage({
    required this.messages,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ChatMessage> messages;
  final String nextCursor;
  final bool hasMore;

  factory ChatMessagesPage.fromJson(Map<String, dynamic> json) =>
      ChatMessagesPage(
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['next_cursor'] as String? ?? '',
        hasMore: json['has_more'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [messages.length, nextCursor, hasMore];
}

class ChatSidebar extends Equatable {
  const ChatSidebar({this.channels = const [], this.dms = const []});

  final List<ChatConversation> channels;
  final List<ChatConversation> dms;

  factory ChatSidebar.fromJson(Map<String, dynamic> json) => ChatSidebar(
        channels: (json['channels'] as List<dynamic>? ?? [])
            .map((e) => ChatConversation.fromJson(e as Map<String, dynamic>))
            .toList(),
        dms: (json['dms'] as List<dynamic>? ?? [])
            .map((e) => ChatConversation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [channels, dms];
}

class ChatAttachmentInput extends Equatable {
  const ChatAttachmentInput({
    required this.fileUrl,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String fileUrl;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'file_url': fileUrl,
        'file_name': fileName,
        'content_type': contentType,
        'size_bytes': sizeBytes,
      };

  @override
  List<Object?> get props => [fileUrl];
}

class ChatPresignResult extends Equatable {
  const ChatPresignResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.objectKey,
  });

  final String uploadUrl;
  final String publicUrl;
  final String objectKey;

  factory ChatPresignResult.fromJson(Map<String, dynamic> json) =>
      ChatPresignResult(
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        objectKey: json['object_key'] as String? ?? '',
      );

  @override
  List<Object?> get props => [uploadUrl, publicUrl];
}
