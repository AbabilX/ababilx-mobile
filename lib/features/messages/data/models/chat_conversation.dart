import 'package:equatable/equatable.dart';

class ChatLastAttachment extends Equatable {
  const ChatLastAttachment({required this.fileName, required this.contentType});

  final String fileName;
  final String contentType;

  factory ChatLastAttachment.fromJson(Map<String, dynamic> json) =>
      ChatLastAttachment(
        fileName: _jsonString(json['file_name'] ?? json['fileName']) ?? '',
        contentType:
            _jsonString(json['content_type'] ?? json['contentType']) ?? '',
      );

  Map<String, dynamic> toJson() => {
    'file_name': fileName,
    'content_type': contentType,
  };

  bool get isImage => contentType.toLowerCase().startsWith('image/');
  bool get isVideo => contentType.toLowerCase().startsWith('video/');
  bool get isAudio => contentType.toLowerCase().startsWith('audio/');
  bool get isPdf {
    final ct = contentType.toLowerCase();
    return ct == 'application/pdf' ||
        ct == 'application/x-pdf' ||
        fileName.toLowerCase().endsWith('.pdf');
  }

  @override
  List<Object?> get props => [fileName, contentType];
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
    this.lastMessageAttachments = const [],
    this.peerUserId,
    this.peerUserName,
    this.peerUserAvatar,
    this.peerUserEmail,
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
  final List<ChatLastAttachment> lastMessageAttachments;
  final String? peerUserId;
  final String? peerUserName;
  final String? peerUserAvatar;
  final String? peerUserEmail;
  final bool peerLeft;
  final bool muted;
  final List<String> memberAvatars;
  final int? memberCount;

  bool get isChannel => type == 'channel';
  bool get isDm => type == 'dm';

  /// Resolved file chips for list preview (API list or legacy single fields).
  List<ChatLastAttachment> get previewAttachments {
    if (lastMessageAttachments.isNotEmpty) return lastMessageAttachments;
    final type = lastMessageAttachmentType?.trim() ?? '';
    final name = lastMessageAttachmentName?.trim() ?? '';
    if (type.isEmpty && name.isEmpty) return const [];
    return [ChatLastAttachment(fileName: name, contentType: type)];
  }

  String displayTitle(String? currentUserId) {
    if (isChannel) return name ?? slug ?? 'Channel';
    return peerUserName ?? 'Direct message';
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final attsRaw =
        json['last_message_attachments'] ?? json['lastMessageAttachments'];
    final parsedAtts = <ChatLastAttachment>[];
    if (attsRaw is List) {
      for (final e in attsRaw) {
        if (e is Map<String, dynamic>) {
          parsedAtts.add(ChatLastAttachment.fromJson(e));
        } else if (e is Map) {
          parsedAtts.add(
            ChatLastAttachment.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    return ChatConversation(
      id: _jsonString(json['id']) ?? '',
      teamId: _jsonString(json['team_id']) ?? '',
      type: _jsonString(json['type']) ?? 'channel',
      name: _jsonString(json['name']),
      slug: _jsonString(json['slug']),
      isPrivate: json['is_private'] as bool? ?? false,
      createdBy: _jsonString(json['created_by']),
      createdAt: _jsonString(json['created_at']) ?? '',
      archivedAt: _jsonString(json['archived_at']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageAt: _jsonString(json['last_message_at']),
      lastMessageBody: _jsonString(json['last_message_body']),
      lastMessageUserId: _jsonString(
        json['last_message_user_id'] ?? json['lastMessageUserId'],
      ),
      lastMessageAttachmentType: _jsonString(
        json['last_message_attachment_type'],
      ),
      lastMessageAttachmentName: _jsonString(
        json['last_message_attachment_name'],
      ),
      lastMessageAttachments: parsedAtts,
      peerUserId: _jsonString(json['peer_user_id']),
      peerUserName: _jsonString(json['peer_user_name']),
      peerUserAvatar: _jsonString(json['peer_user_avatar']),
      peerUserEmail: _jsonString(
        json['peer_user_email'] ?? json['peerUserEmail'],
      ),
      peerLeft: json['peer_left'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
      memberAvatars: (json['member_avatars'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      memberCount: (json['member_count'] as num?)?.toInt(),
    );
  }

  ChatConversation copyWith({
    int? unreadCount,
    String? lastMessageAt,
    String? lastMessageBody,
    String? lastMessageUserId,
    String? lastMessageAttachmentType,
    String? lastMessageAttachmentName,
    List<ChatLastAttachment>? lastMessageAttachments,
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
    lastMessageAttachments: clearLastMessageAttachment
        ? const []
        : (lastMessageAttachments ?? this.lastMessageAttachments),
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
    lastMessageUserId,
    lastMessageAttachmentType,
    lastMessageAttachmentName,
    lastMessageAttachments,
    muted,
    name,
    peerUserName,
  ];
}

String? _jsonString(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
  return value.toString();
}
