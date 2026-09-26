import 'package:equatable/equatable.dart';

import '../../../../shared/text/display_name.dart';
import 'group_member_perms.dart';

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
    this.peerUserCover,
    this.peerUserEmail,
    this.peerLeft = false,
    this.isSelf = false,
    this.peerPrivacy = false,
    this.receiptsHidden = false,
    this.myReceiptsHidden = false,
    this.privateChat = false,
    this.privateChatBy = '',
    this.lastMessagePrivate = false,
    this.canMessage = true,
    this.lockReason = '',
    this.plaintextUntilKeyed = false,
    this.requestState = 'none',
    this.muted = false,
    this.mutedUntil,
    this.muteMode = 'all',
    this.pinned = false,
    this.memberAvatars = const [],
    this.memberCount,
    this.avatarUrl,
    this.bannerUrl,
    this.description,
    this.editInfoRole = 'admin',
    this.addMembersRole = 'admin',
    this.myRole = '',
    this.groupPrivacy = false,
    this.myPermissions,
    this.defaultPermissions,
  });

  final String id;
  final String teamId;
  final String scope; // personal | workspace
  final String type; // channel | dm | group | webhook
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

  /// The peer's profile cover (`users.cover_url`). Drawn behind the details
  /// header the same way [bannerUrl] is drawn for a group.
  final String? peerUserCover;
  final String? peerUserEmail;
  final bool peerLeft;

  /// Note to Self: a personal DM whose two participants are the same account.
  /// The peer fields describe the viewer, so everything that needs a second
  /// person — calls, presence, safety numbers, the request bar, block and
  /// report — is dropped rather than pointed back at them.
  final bool isSelf;

  /// The DM peer has privacy mode on (server migration 0152). This phone then
  /// blocks screenshots in the chat and on a call with them, draws no ticks on
  /// messages sent to them, and shows "Privacy" in place of online/offline.
  /// Live flips arrive as `chat.peer_privacy`; read it through
  /// `peerPrivacyProvider`, which folds those in.
  final bool peerPrivacy;

  /// Some member of this DM switched ticks off (server 0159), so neither side
  /// is shown delivered/read and this phone draws no ticks at all.
  /// [myReceiptsHidden] is this account's own switch. Live changes arrive as
  /// `chat.receipts_hidden`; read through `conversationTicksHiddenProvider`.
  final bool receiptsHidden;
  final bool myReceiptsHidden;

  /// Private chat (server 0160): the server drops each message once the
  /// recipient's phones have it, and neither side sees the other's typing,
  /// ticks, presence or ringing. Either member switched it on
  /// ([privateChatBy]); live changes arrive as `chat.private_chat` — read it
  /// through `conversationPrivateChatProvider`.
  final bool privateChat;
  final String privateChatBy;

  /// The newest message was private and is already gone from the server, so
  /// the last-message fields here describe nothing: the list keeps its own
  /// preview (the phone's newest copy) instead of blanking it.
  final bool lastMessagePrivate;
  final bool canMessage;

  /// Why the composer is closed. Empty when [canMessage] is true.
  /// `blocked`, `connection_removed`, `reconnect_requested`, `account_deleted`.
  final String lockReason;

  bool get isAccountDeleted => lockReason == 'account_deleted';

  /// The server's word that this group may still take plaintext while
  /// somebody in it cannot be sealed to yet (`plaintext_until_keyed`). True
  /// only for a workspace channel converted by the server's migration 0145
  /// that has never had a key. Never inferred from [type]: a group created as
  /// a group refuses to send rather than downgrade — see `ChatKeyNotReady`.
  final bool plaintextUntilKeyed;

  /// Signal-style message request, from this viewer's side:
  /// `incoming` — the peer wrote first and I have not answered, so I get
  /// Accept / Delete / Block over the thread; `outgoing` — I wrote first and
  /// they have not answered; `none` — settled. A workspace colleague is
  /// answered like anyone else since the server's migration 0145.
  final String requestState;

  /// A note to self can never be a request: the server reports `none`, and a
  /// bar offering to accept or block yourself would replace the composer.
  bool get isIncomingRequest => !isSelf && requestState == 'incoming';

  /// The server's answer at fetch time. A timed mute can lapse while the row
  /// sits in memory, so UI reads `isMutedNow` (chat-mute/mute_choice.dart).
  final bool muted;

  /// When a timed mute ends; null = until unmuted (migration 0162).
  final DateTime? mutedUntil;

  /// `all` or `mentions` — the latter lets @mentions and replies through.
  final String muteMode;

  /// Kept at the top of this member's own list. Per-member like [muted], so
  /// pinning a group reorders it for nobody else. The server caps it at four
  /// (`chat.MaxPinnedConversations`) and answers a fifth with 409
  /// `chat_pin_limit`.
  final bool pinned;
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
  final String myRole; // admin | member | '' when the server did not say

  /// The group's own privacy switch, set by its admins (server 0154): no
  /// forwarding, no Save or Share of its media or pictures, and a member list
  /// only admins see in full. Independent of anyone's privacy mode.
  final bool groupPrivacy;

  /// What the viewer may do in this group (server 0157), everything for an
  /// admin; and what every member may do. Null on a DM, and on a server that
  /// predates member permissions — `GroupPermissions` falls back then.
  final GroupMemberPerms? myPermissions;
  final GroupMemberPerms? defaultPermissions;

  /// The viewer's admin row in this conversation. What may be done with it
  /// is decided by `GroupPermissions` in chat-details — from this row and the
  /// group's two switches, and nothing about any team.
  bool get iAmAdmin => myRole == 'admin';

  /// Whether this conversation has a second person in it — the precondition
  /// for a nickname, a safety number, a call, a block, a report and
  /// groups-in-common. A note to self is a DM and has no peer, which is the
  /// one case a bare `isDm` check gets wrong.
  bool get hasDmPeer => isDm && !isSelf && (peerUserId ?? '').isNotEmpty;

  /// Cover behind the details header: a group's own banner, or a DM peer's
  /// profile cover. Empty means the header stays plain.
  String? get headerBannerUrl => isDm ? peerUserCover : bannerUrl;

  bool get isChannel => type == 'channel';
  bool get isDm => type == 'dm';
  bool get isGroup => type == 'group';

  /// A one-way workspace feed filled by inbound HTTP. It is a channel in every
  /// respect — roster, name, members, notifications — except that nobody may
  /// post into it, which the server says on its own by returning
  /// `can_message: false`. Do not re-derive that from the type here, or a
  /// future read-only channel would need the same rule written twice.
  bool get isWebhook => type == 'webhook';
  bool get isPersonal => scope == 'personal';
  bool get isGroupConversation => isChannel || isGroup || isWebhook;

  /// Whether this conversation has a group call (the LiveKit room) to start or
  /// join: a workspace channel or a personal group you may post into. Mirrors
  /// the server's `groupCallConversation`, which refuses a DM (that is the
  /// peer-to-peer `voice_calls` path) and then applies the send gate. A
  /// webhook feed is named out as well, because the server refuses it by type.
  bool get canGroupCall => (isChannel || isGroup) && canMessage;

  /// Whether this conversation's text is end-to-end encrypted.
  ///
  /// The mirror of `e2eeEligible` on the server, and it must stay one: encrypt
  /// where the server does not expect it and the send is a 400; send plaintext
  /// where it does and the send is a 409.
  ///
  /// DMs, and groups. Every group is personal since the server's migration
  /// 0145, a converted workspace channel included; one with no key yet keeps
  /// taking plaintext until a member's device mints the first key, and what
  /// was written before that stays plaintext (see `ChatKeyNotReady`).
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
    if (isSelf) return 'Note to Self';
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
      peerUserCover: _jsonString(json['peer_user_cover']),
      peerUserEmail: _jsonString(
        json['peer_user_email'] ?? json['peerUserEmail'],
      ),
      peerLeft: json['peer_left'] as bool? ?? false,
      isSelf: json['is_self'] as bool? ?? false,
      peerPrivacy: json['peer_privacy'] as bool? ?? false,
      receiptsHidden: json['receipts_hidden'] as bool? ?? false,
      myReceiptsHidden: json['my_receipts_hidden'] as bool? ?? false,
      privateChat: json['private_chat'] as bool? ?? false,
      privateChatBy: _jsonString(json['private_chat_by']) ?? '',
      lastMessagePrivate: json['last_message_private'] as bool? ?? false,
      canMessage: json['can_message'] as bool? ?? true,
      lockReason: _jsonString(json['lock_reason']) ?? '',
      plaintextUntilKeyed: json['plaintext_until_keyed'] as bool? ?? false,
      requestState: json['request_state'] as String? ?? 'none',
      muted: json['muted'] as bool? ?? false,
      mutedUntil: DateTime.tryParse(
        json['muted_until'] as String? ?? '',
      )?.toLocal(),
      muteMode: json['mute_mode'] as String? ?? 'all',
      pinned: json['pinned'] as bool? ?? false,
      memberAvatars: (json['member_avatars'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      memberCount: (json['member_count'] as num?)?.toInt(),
      avatarUrl: _jsonString(json['avatar_url']),
      bannerUrl: _jsonString(json['banner_url']),
      description: _jsonString(json['description']),
      editInfoRole: _jsonString(json['edit_info_role']) ?? 'admin',
      addMembersRole: _jsonString(json['add_members_role']) ?? 'admin',
      myRole: _jsonString(json['my_role']) ?? '',
      groupPrivacy: json['group_privacy'] as bool? ?? false,
      myPermissions: GroupMemberPerms.maybeFromJson(json['my_permissions']),
      defaultPermissions: GroupMemberPerms.maybeFromJson(
        json['default_permissions'],
      ),
    );
  }

  ChatConversation withoutMessagePreview() => copyWith(
    unreadCount: 0,
    lastMessageAt: '',
    lastMessageBody: '',
    lastMessageUserId: '',
    clearLastMessageAttachment: true,
    clearLastMessageEncryption: true,
  );

  ChatConversation copyWith({
    int? unreadCount,
    String? lastMessageAt,
    String? lastMessageBody,
    String? lastMessageUserId,
    String? lastMessageAttachmentType,
    String? lastMessageAttachmentName,
    List<ChatLastAttachment>? lastMessageAttachments,
    bool clearLastMessageAttachment = false,
    String? lastMessageEncryptedBody,
    String? lastMessageEncryptionNonce,
    int? lastMessageEncryptionVersion,
    int? lastMessageEncryptionKeyVersion,
    // A plaintext last message has no ciphertext, and `null` above means
    // "keep": without this a sealed row could never say its newest message
    // is not sealed.
    bool clearLastMessageEncryption = false,
    bool? muted,
    DateTime? mutedUntil,
    // null above means "keep"; an "Always" mute has to clear the end time.
    bool clearMutedUntil = false,
    String? muteMode,
    bool? pinned,
    String? name,
    String? requestState,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    String? editInfoRole,
    String? addMembersRole,
    String? myRole,
    bool? groupPrivacy,
    bool? privateChat,
    String? privateChatBy,
    bool? lastMessagePrivate,
    GroupMemberPerms? myPermissions,
    GroupMemberPerms? defaultPermissions,
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
    lastMessageEncryptedBody: clearLastMessageEncryption
        ? null
        : (lastMessageEncryptedBody ?? this.lastMessageEncryptedBody),
    lastMessageEncryptionNonce: clearLastMessageEncryption
        ? null
        : (lastMessageEncryptionNonce ?? this.lastMessageEncryptionNonce),
    lastMessageEncryptionVersion: clearLastMessageEncryption
        ? null
        : (lastMessageEncryptionVersion ?? this.lastMessageEncryptionVersion),
    lastMessageEncryptionKeyVersion: clearLastMessageEncryption
        ? null
        : (lastMessageEncryptionKeyVersion ??
              this.lastMessageEncryptionKeyVersion),
    peerUserId: peerUserId,
    peerUserName: peerUserName,
    peerUserAvatar: peerUserAvatar,
    peerUserCover: peerUserCover,
    peerLeft: peerLeft,
    isSelf: isSelf,
    peerPrivacy: peerPrivacy,
    receiptsHidden: receiptsHidden,
    myReceiptsHidden: myReceiptsHidden,
    privateChat: privateChat ?? this.privateChat,
    privateChatBy: privateChatBy ?? this.privateChatBy,
    lastMessagePrivate: lastMessagePrivate ?? this.lastMessagePrivate,
    canMessage: canMessage,
    lockReason: lockReason,
    plaintextUntilKeyed: plaintextUntilKeyed,
    requestState: requestState ?? this.requestState,
    muted: muted ?? this.muted,
    mutedUntil: clearMutedUntil ? null : (mutedUntil ?? this.mutedUntil),
    muteMode: muteMode ?? this.muteMode,
    pinned: pinned ?? this.pinned,
    memberAvatars: memberAvatars,
    memberCount: memberCount,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bannerUrl: bannerUrl ?? this.bannerUrl,
    description: description ?? this.description,
    editInfoRole: editInfoRole ?? this.editInfoRole,
    addMembersRole: addMembersRole ?? this.addMembersRole,
    myRole: myRole ?? this.myRole,
    groupPrivacy: groupPrivacy ?? this.groupPrivacy,
    myPermissions: myPermissions ?? this.myPermissions,
    defaultPermissions: defaultPermissions ?? this.defaultPermissions,
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
    mutedUntil,
    muteMode,
    pinned,
    name,
    peerUserName,
    scope,
    isSelf,
    peerPrivacy,
    receiptsHidden,
    myReceiptsHidden,
    privateChat,
    privateChatBy,
    lastMessagePrivate,
    canMessage,
    lockReason,
    plaintextUntilKeyed,
    requestState,
    description,
    avatarUrl,
    bannerUrl,
    peerUserCover,
    myRole,
    groupPrivacy,
    myPermissions,
    defaultPermissions,
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
