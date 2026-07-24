import 'package:equatable/equatable.dart';

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
