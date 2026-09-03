import 'package:equatable/equatable.dart';

class ChatMember extends Equatable {
  const ChatMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.joinedAt,
    this.role = 'member',
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String joinedAt;

  /// admin | member. Personal groups answer to this column; a workspace
  /// channel leaves everyone "member" and takes management from the team.
  final String role;

  bool get isAdmin => role == 'admin';

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
    userId: json['user_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    joinedAt: json['joined_at'] as String? ?? '',
    role: json['role'] as String? ?? 'member',
  );

  @override
  List<Object?> get props => [userId];
}
