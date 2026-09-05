import 'package:equatable/equatable.dart';

import '../../../../shared/text/display_name.dart';

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
    this.scope = 'workspace',
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
    this.lastMessageEncryptedBody,
    this.lastMessageEncryptionNonce,
    this.lastMessageEncryptionVersion,
    this.lastMessageEncryptionKeyVersion,
    this.peerUserId,
    this.peerUserName,
    this.peerUserAvatar,
    this.peerUserEmail,
    this.peerLeft = false,
    this.canMessage = true,
    this.requestState = 'none',
    this.muted = false,
    this.memberAvatars = const [],
    this.memberCount,
    this.avatarUrl,
    this.bannerUrl,
    this.description,
    this.editInfoRole = 'admin',
    this.addMembersRole = 'admin',
    this.myRole = 'member',
  });

  final String id;
  final String teamId;
  final String scope; // personal | workspace
  final String type; // channel | dm | group
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
  final String? lastMessageEncryptedBody;
  final String? lastMessageEncryptionNonce;
  final int? lastMessageEncryptionVersion;
  final int? lastMessageEncryptionKeyVersion;
  final String? peerUserId;
  final String? peerUserName;
  final String? peerUserAvatar;
  final String? peerUserEmail;
  final bool peerLeft;
  final bool canMessage;

  /// Signal-style message request, from this viewer's side:
  /// `incoming` — the peer wrote first and I have not answered, so I get
  /// Accept / Delete / Block over the thread; `outgoing` — I wrote first and
  /// they have not answered; `none` — settled, or a workspace colleague, who
  /// was never a request.
  final String requestState;

  bool get isIncomingRequest => requestState == 'incoming';
  final bool muted;
  final List<String> memberAvatars;
  final int? memberCount;

  /// Personal-group identity and permission switches, straight from the
  /// server. `myRole` is the viewer's own role, so the details screen never
  /// re-derives a permission the server already decided.
  final String? avatarUrl;

  /// The wide image behind the details header. Separate from [avatarUrl]: a
  /// circle and a cover photo are never the same crop of the same picture.
  final String? bannerUrl;
  final String? description;
  final String editInfoRole; // admin | member
  final String addMembersRole; // admin | member
  final String myRole; // admin | member

  bool get iAmAdmin => myRole == 'admin';

  /// Workspace channels take management from the team, which the old details
  /// dialog approximated as "anyone but a personal non-creator".
  bool get canEditGroupInfo =>
      !isPersonal || iAmAdmin || editInfoRole == 'member';
  bool get canAddGroupMembers =>
      !isPersonal || iAmAdmin || addMembersRole == 'member';

  /// Configuring a personal group — roles, removal, deletion — is always
  /// admin-only and deliberately not itself a switch.
  bool get canConfigureGroup => !isPersonal || iAmAdmin;

  bool get isChannel => type == 'channel';
  bool get isDm => type == 'dm';
  bool get isGroup => type == 'group';
  bool get isPersonal => scope == 'personal';
  bool get isGroupConversation => isChannel || isGroup;

  /// Whether this conversation's text is end-to-end encrypted.
  ///
  /// The mirror of `e2eeEligible` on the server, and it must stay one: encrypt
  /// where the server does not expect it and the send is a 400; send plaintext
  /// where it does and the send is a 409.
  ///
  /// DMs in either scope, and personal groups. Workspace channels never — they
  /// are a searchable shared record and server-side search cannot read
  /// ciphertext.
  bool get isEncrypted => isDm || (isPersonal && isGroup);

  /// Resolved file chips for list preview (API list or legacy single fields).
  List<ChatLastAttachment> get previewAttachments {
    if (lastMessageAttachments.isNotEmpty) return lastMessageAttachments;
    final type = lastMessageAttachmentType?.trim() ?? '';
    final name = lastMessageAttachmentName?.trim() ?? '';
    if (type.isEmpty && name.isEmpty) return const [];
    return [ChatLastAttachment(fileName: name, contentType: type)];
  }

  /// The name shown in the list row, the chat header and every notification.
  ///
  /// Sanitised, because it is whatever the other side typed: a name may carry
  /// bidi overrides that flip the rest of the row, newlines that break its
  /// layout, or a stack of combining marks that draws outside it.
  String displayTitle(String? currentUserId) {
    if (isGroupConversation) {
      return safeDisplayName(name ?? slug, fallback: 'Group');
    }
    return safeDisplayName(peerUserName, fallback: 'Direct message');
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
      scope: _jsonString(json['scope']) ?? 'workspace',
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
      lastMessageEncryptedBody: _jsonString(
        json['last_message_encrypted_body'],
      ),
      lastMessageEncryptionNonce: _jsonString(
        json['last_message_encryption_nonce'],
      ),
      lastMessageEncryptionVersion:
          (json['last_message_encryption_version'] as num?)?.toInt(),
      lastMessageEncryptionKeyVersion:
          (json['last_message_encryption_key_version'] as num?)?.toInt(),
      peerUserId: _jsonString(json['peer_user_id']),
      peerUserName: _jsonString(json['peer_user_name']),
      peerUserAvatar: _jsonString(json['peer_user_avatar']),
      peerUserEmail: _jsonString(
        json['peer_user_email'] ?? json['peerUserEmail'],
      ),
      peerLeft: json['peer_left'] as bool? ?? false,
      canMessage: json['can_message'] as bool? ?? true,
      requestState: json['request_state'] as String? ?? 'none',
      muted: json['muted'] as bool? ?? false,
      memberAvatars: (json['member_avatars'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      memberCount: (json['member_count'] as num?)?.toInt(),
      avatarUrl: _jsonString(json['avatar_url']),
      bannerUrl: _jsonString(json['banner_url']),
      description: _jsonString(json['description']),
      editInfoRole: _jsonString(json['edit_info_role']) ?? 'admin',
      addMembersRole: _jsonString(json['add_members_role']) ?? 'admin',
      myRole: _jsonString(json['my_role']) ?? 'member',
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
    String? requestState,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    String? editInfoRole,
    String? addMembersRole,
    String? myRole,
  }) => ChatConversation(
    id: id,
    teamId: teamId,
    scope: scope,
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
    lastMessageEncryptedBody: lastMessageEncryptedBody,
    lastMessageEncryptionNonce: lastMessageEncryptionNonce,
    lastMessageEncryptionVersion: lastMessageEncryptionVersion,
    lastMessageEncryptionKeyVersion: lastMessageEncryptionKeyVersion,
    peerUserId: peerUserId,
    peerUserName: peerUserName,
    peerUserAvatar: peerUserAvatar,
    peerLeft: peerLeft,
    canMessage: canMessage,
    requestState: requestState ?? this.requestState,
    muted: muted ?? this.muted,
    memberAvatars: memberAvatars,
    memberCount: memberCount,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bannerUrl: bannerUrl ?? this.bannerUrl,
    description: description ?? this.description,
    editInfoRole: editInfoRole ?? this.editInfoRole,
    addMembersRole: addMembersRole ?? this.addMembersRole,
    myRole: myRole ?? this.myRole,
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
    scope,
    canMessage,
    requestState,
    description,
    avatarUrl,
    bannerUrl,
    myRole,
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
