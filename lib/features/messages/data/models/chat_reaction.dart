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

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

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

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'count': count,
        'users': users.map((u) => u.toJson()).toList(),
        'reacted_by_me': reactedByMe,
      };

  @override
  List<Object?> get props => [emoji, count, reactedByMe];
}
