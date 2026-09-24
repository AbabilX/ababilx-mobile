import 'package:equatable/equatable.dart';

import 'group_member_perms.dart';

class ChatMember extends Equatable {
  const ChatMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.joinedAt,
    this.role = 'member',
    this.tag = '',
    this.permissions,
    this.restricted = false,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String joinedAt;

  /// admin | member. Personal groups answer to this column; a workspace
  /// channel leaves everyone "member" and takes management from the team.
  final String role;

  /// Short label shown beside the name in the group (server 0157).
  final String tag;

  /// What this member may do, and whether an admin switched anything off for
  /// them alone. Sent to admins only; null for everyone else.
  final GroupMemberPerms? permissions;
  final bool restricted;

  bool get isAdmin => role == 'admin';

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
    userId: json['user_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    joinedAt: json['joined_at'] as String? ?? '',
    role: json['role'] as String? ?? 'member',
    tag: json['tag'] as String? ?? '',
    permissions: GroupMemberPerms.maybeFromJson(json['permissions']),
    restricted: json['restricted'] == true,
  );

  ChatMember copyWith({
    String? role,
    String? tag,
    GroupMemberPerms? permissions,
    bool? restricted,
  }) => ChatMember(
    userId: userId,
    name: name,
    avatarUrl: avatarUrl,
    joinedAt: joinedAt,
    role: role ?? this.role,
    tag: tag ?? this.tag,
    permissions: permissions ?? this.permissions,
    restricted: restricted ?? this.restricted,
  );

  @override
  List<Object?> get props => [userId, role, tag, permissions, restricted];
}
