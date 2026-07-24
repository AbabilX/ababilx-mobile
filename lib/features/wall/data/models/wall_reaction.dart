import 'package:equatable/equatable.dart';

class WallReactionUser extends Equatable {
  const WallReactionUser({required this.userId, this.name});

  final String userId;
  final String? name;

  factory WallReactionUser.fromJson(Map<String, dynamic> json) =>
      WallReactionUser(
        userId: json['user_id'] as String? ?? '',
        name: json['user_name'] as String? ?? json['name'] as String?,
      );

  @override
  List<Object?> get props => [userId];
}

class WallReactionGroup extends Equatable {
  const WallReactionGroup({
    required this.emoji,
    required this.count,
    this.users = const [],
    this.reactedByMe = false,
  });

  final String emoji;
  final int count;
  final List<WallReactionUser> users;
  final bool reactedByMe;

  factory WallReactionGroup.fromJson(Map<String, dynamic> json) =>
      WallReactionGroup(
        emoji: json['emoji'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        users: (json['users'] as List<dynamic>? ?? [])
            .map((e) => WallReactionUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactedByMe: json['reacted_by_me'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [emoji, count, reactedByMe];
}
