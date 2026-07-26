import 'package:equatable/equatable.dart';

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

  factory ChatConversation.fromJson(
    Map<String, dynamic> json,
  ) => ChatConversation(
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
    lastMessageAttachmentType: json['last_message_attachment_type'] as String?,
    lastMessageAttachmentName: json['last_message_attachment_name'] as String?,
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
    bool clearLastMessageAttachment = false,
    bool? muted,
    String? name,
  }) => ChatConversation(
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
    lastMessageAttachmentType: clearLastMessageAttachment
        ? null
        : (lastMessageAttachmentType ?? this.lastMessageAttachmentType),
    lastMessageAttachmentName: clearLastMessageAttachment
        ? null
        : (lastMessageAttachmentName ?? this.lastMessageAttachmentName),
    peerUserId: peerUserId,
    peerUserName: peerUserName,
    peerUserAvatar: peerUserAvatar,
    peerLeft: peerLeft,
    muted: muted ?? this.muted,
    memberAvatars: memberAvatars,
    memberCount: memberCount,
  );

  @override
  List<Object?> get props => [
    id,
    unreadCount,
    lastMessageAt,
    lastMessageBody,
    lastMessageAttachmentType,
    lastMessageAttachmentName,
    muted,
    name,
  ];
}
