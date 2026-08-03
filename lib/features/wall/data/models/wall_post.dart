import 'package:equatable/equatable.dart';

import 'wall_attachment.dart';
import 'wall_comment.dart';
import 'wall_reaction.dart';

class WallPost extends Equatable {
  const WallPost({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.category,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userAvatarUrl,
    this.userIsPremium = false,
    this.attachments = const [],
    this.comments = const [],
    this.reactions = const [],
    this.commentCount = 0,
    this.savedByMe = false,
  });

  final String id;
  final String teamId;
  final String userId;
  final String category;
  final String body;
  final String createdAt;
  final String updatedAt;
  final String? userName;
  final String? userAvatarUrl;
  final bool userIsPremium;
  final List<WallAttachment> attachments;
  final List<WallComment> comments;
  final List<WallReactionGroup> reactions;
  final int commentCount;
  final bool savedByMe;

  factory WallPost.fromJson(Map<String, dynamic> json) => WallPost(
    id: json['id'] as String? ?? '',
    teamId: json['team_id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    category: json['category'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
    userName: json['user_name'] as String?,
    userAvatarUrl: json['user_avatar_url'] as String?,
    userIsPremium: json['user_is_premium'] as bool? ?? false,
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((e) => WallAttachment.fromJson(e as Map<String, dynamic>))
        .toList(),
    comments: (json['comments'] as List<dynamic>? ?? [])
        .map((e) => WallComment.fromJson(e as Map<String, dynamic>))
        .toList(),
    reactions: (json['reactions'] as List<dynamic>? ?? [])
        .map((e) => WallReactionGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
    commentCount: json['comment_count'] as int? ?? 0,
    savedByMe: json['saved_by_me'] as bool? ?? false,
  );

  WallPost copyWith({
    String? body,
    List<WallComment>? comments,
    List<WallReactionGroup>? reactions,
    int? commentCount,
    bool? savedByMe,
  }) => WallPost(
    id: id,
    teamId: teamId,
    userId: userId,
    category: category,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt,
    userName: userName,
    userAvatarUrl: userAvatarUrl,
    userIsPremium: userIsPremium,
    attachments: attachments,
    comments: comments ?? this.comments,
    reactions: reactions ?? this.reactions,
    commentCount: commentCount ?? this.commentCount,
    savedByMe: savedByMe ?? this.savedByMe,
  );

  @override
  List<Object?> get props => [id, body, commentCount, savedByMe, reactions];
}
