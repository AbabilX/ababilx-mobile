import 'package:equatable/equatable.dart';

import 'wall_attachment.dart';
import 'wall_reaction.dart';

class WallComment extends Equatable {
  const WallComment({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.body,
    required this.createdAt,
    this.userName,
    this.userAvatarUrl,
    this.userIsPremium = false,
    this.attachments = const [],
    this.reactions = const [],
  });

  final String id;
  final String postId;
  final String userId;
  final String? parentId;
  final String body;
  final String createdAt;
  final String? userName;
  final String? userAvatarUrl;
  final bool userIsPremium;
  final List<WallAttachment> attachments;
  final List<WallReactionGroup> reactions;

  factory WallComment.fromJson(Map<String, dynamic> json) => WallComment(
    id: json['id'] as String? ?? '',
    postId: json['post_id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    parentId: json['parent_id'] as String?,
    body: json['body'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    userName: json['user_name'] as String?,
    userAvatarUrl: json['user_avatar_url'] as String?,
    userIsPremium: json['user_is_premium'] as bool? ?? false,
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((e) => WallAttachment.fromJson(e as Map<String, dynamic>))
        .toList(),
    reactions: (json['reactions'] as List<dynamic>? ?? [])
        .map((e) => WallReactionGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  WallComment copyWith({String? body, List<WallReactionGroup>? reactions}) =>
      WallComment(
        id: id,
        postId: postId,
        userId: userId,
        parentId: parentId,
        body: body ?? this.body,
        createdAt: createdAt,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        userIsPremium: userIsPremium,
        attachments: attachments,
        reactions: reactions ?? this.reactions,
      );

  @override
  List<Object?> get props => [id, body, reactions];
}
