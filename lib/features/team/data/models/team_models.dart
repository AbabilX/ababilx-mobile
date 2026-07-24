import 'package:equatable/equatable.dart';

class Team extends Equatable {
  const Team({
    required this.id,
    required this.ownerUserId,
    required this.name,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String? avatarUrl;
  final String createdAt;

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String? ?? '',
        ownerUserId: json['owner_user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, name];
}

class TeamMember extends Equatable {
  const TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.name,
    this.username,
    this.avatarUrl,
    this.email,
  });

  final String id;
  final String teamId;
  final String userId;
  final String role;
  final String status;
  final String joinedAt;
  final String? name;
  final String? username;
  final String? avatarUrl;
  final String? email;

  String get displayName => name ?? username ?? email ?? userId;

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'] as String? ?? '',
        teamId: json['team_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        role: json['role'] as String? ?? 'member',
        status: json['status'] as String? ?? 'active',
        joinedAt: json['joined_at'] as String? ?? '',
        name: json['name'] as String?,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        email: json['email'] as String?,
      );

  @override
  List<Object?> get props => [userId, name, role];
}

class TeamDetail extends Equatable {
  const TeamDetail({
    this.team,
    this.members = const [],
    this.myRole = '',
    this.teamIsPremium = false,
    this.crmAccess = false,
  });

  final Team? team;
  final List<TeamMember> members;
  final String myRole;
  final bool teamIsPremium;

  /// Per-member CRM allowlist (leader/manager implicit; member needs grant).
  final bool crmAccess;

  bool get hasTeam => team != null;

  /// Same as web: team premium + member CRM access unlocks CRM nav/view.
  bool get canViewCrm => hasTeam && teamIsPremium && crmAccess;

  factory TeamDetail.fromJson(Map<String, dynamic> json) {
    final teamJson = json['team'];
    return TeamDetail(
      team: teamJson != null
          ? Team.fromJson(teamJson as Map<String, dynamic>)
          : null,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      myRole: json['my_role'] as String? ?? '',
      teamIsPremium: json['team_is_premium'] as bool? ?? false,
      crmAccess: json['crm_access'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [team, members.length, myRole, teamIsPremium, crmAccess];
}
