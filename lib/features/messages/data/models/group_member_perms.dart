import 'package:equatable/equatable.dart';

/// One group permission set (server migration 0157) — Telegram's "What can
/// this user do?". The server sends two of these on a group: what every
/// member may do (`default_permissions`) and what the viewer may do
/// (`my_permissions`, everything for an admin). A member exception can only
/// take away: a switch left on while the group has it off stays off.
///
/// Wire names match `services/chat/groupperms` on the server. A missing key
/// reads as `false` — a set is always sent whole, and a permission nobody said
/// was granted must not be assumed.
class GroupMemberPerms extends Equatable {
  const GroupMemberPerms({
    this.sendMessages = false,
    this.sendPhotos = false,
    this.sendVideos = false,
    this.sendFiles = false,
    this.sendMusic = false,
    this.addUsers = false,
    this.pinMessages = false,
    this.changeInfo = false,
    this.startCalls = false,
    this.forward = false,
    this.editOwnTag = false,
  });

  static const all = GroupMemberPerms(
    sendMessages: true,
    sendPhotos: true,
    sendVideos: true,
    sendFiles: true,
    sendMusic: true,
    addUsers: true,
    pinMessages: true,
    changeInfo: true,
    startCalls: true,
    forward: true,
    editOwnTag: true,
  );

  final bool sendMessages;
  final bool sendPhotos;
  final bool sendVideos;
  final bool sendFiles;
  final bool sendMusic;
  final bool addUsers;
  final bool pinMessages;
  final bool changeInfo;
  final bool startCalls;
  final bool forward;
  final bool editOwnTag;

  /// Without Send Messages nothing is sent at all, so the media kinds fall
  /// with it — the server's own rule.
  bool allowsMedia(GroupMediaKind kind) {
    if (!sendMessages) return false;
    return switch (kind) {
      GroupMediaKind.photos => sendPhotos,
      GroupMediaKind.videos => sendVideos,
      GroupMediaKind.files => sendFiles,
      GroupMediaKind.music => sendMusic,
    };
  }

  /// "N/4" on the Send Media row.
  int get mediaAllowedCount =>
      GroupMediaKind.values.where((k) => media(k)).length;

  /// The raw sub-switch, ignoring Send Messages (the screen draws both).
  bool media(GroupMediaKind kind) => switch (kind) {
    GroupMediaKind.photos => sendPhotos,
    GroupMediaKind.videos => sendVideos,
    GroupMediaKind.files => sendFiles,
    GroupMediaKind.music => sendMusic,
  };

  GroupMemberPerms withMedia(GroupMediaKind kind, bool on) => switch (kind) {
    GroupMediaKind.photos => copyWith(sendPhotos: on),
    GroupMediaKind.videos => copyWith(sendVideos: on),
    GroupMediaKind.files => copyWith(sendFiles: on),
    GroupMediaKind.music => copyWith(sendMusic: on),
  };

  factory GroupMemberPerms.fromJson(Map<String, dynamic> json) {
    bool b(String key) => json[key] == true;
    return GroupMemberPerms(
      sendMessages: b('send_messages'),
      sendPhotos: b('send_photos'),
      sendVideos: b('send_videos'),
      sendFiles: b('send_files'),
      sendMusic: b('send_music'),
      addUsers: b('add_users'),
      pinMessages: b('pin_messages'),
      changeInfo: b('change_info'),
      startCalls: b('start_calls'),
      forward: b('forward'),
      editOwnTag: b('edit_own_tag'),
    );
  }

  /// Null when the server sent nothing (a DM, or a server older than 0157).
  static GroupMemberPerms? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) return GroupMemberPerms.fromJson(value);
    if (value is Map) {
      return GroupMemberPerms.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'send_messages': sendMessages,
    'send_photos': sendPhotos,
    'send_videos': sendVideos,
    'send_files': sendFiles,
    'send_music': sendMusic,
    'add_users': addUsers,
    'pin_messages': pinMessages,
    'change_info': changeInfo,
    'start_calls': startCalls,
    'forward': forward,
    'edit_own_tag': editOwnTag,
  };

  GroupMemberPerms copyWith({
    bool? sendMessages,
    bool? sendPhotos,
    bool? sendVideos,
    bool? sendFiles,
    bool? sendMusic,
    bool? addUsers,
    bool? pinMessages,
    bool? changeInfo,
    bool? startCalls,
    bool? forward,
    bool? editOwnTag,
  }) => GroupMemberPerms(
    sendMessages: sendMessages ?? this.sendMessages,
    sendPhotos: sendPhotos ?? this.sendPhotos,
    sendVideos: sendVideos ?? this.sendVideos,
    sendFiles: sendFiles ?? this.sendFiles,
    sendMusic: sendMusic ?? this.sendMusic,
    addUsers: addUsers ?? this.addUsers,
    pinMessages: pinMessages ?? this.pinMessages,
    changeInfo: changeInfo ?? this.changeInfo,
    startCalls: startCalls ?? this.startCalls,
    forward: forward ?? this.forward,
    editOwnTag: editOwnTag ?? this.editOwnTag,
  );

  @override
  List<Object?> get props => [
    sendMessages,
    sendPhotos,
    sendVideos,
    sendFiles,
    sendMusic,
    addUsers,
    pinMessages,
    changeInfo,
    startCalls,
    forward,
    editOwnTag,
  ];
}

/// The four "Send Media" kinds. A voice note is none of them: it rides on
/// Send Messages.
enum GroupMediaKind { photos, videos, files, music }

/// Which kind an attachment needs, or null for a voice note — the server's
/// `groupperms.MediaBit`, same prefixes (every recorder names its file
/// `voice-…`).
GroupMediaKind? groupMediaKindFor(String contentType, String fileName) {
  final ct = contentType.split(';').first.trim().toLowerCase();
  if (ct.startsWith('image/')) return GroupMediaKind.photos;
  if (ct.startsWith('video/')) return GroupMediaKind.videos;
  if (ct.startsWith('audio/')) {
    final base = fileName.replaceAll('\\', '/').split('/').last.toLowerCase();
    return base.startsWith('voice-') ? null : GroupMediaKind.music;
  }
  return GroupMediaKind.files;
}
