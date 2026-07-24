import 'package:equatable/equatable.dart';

import 'wall_comment.dart';
import 'wall_post.dart';

class WallSearchPostHit extends Equatable {
  const WallSearchPostHit({
    required this.post,
    required this.excerpt,
    required this.matchIn,
  });

  final WallPost post;
  final String excerpt;
  final String matchIn;

  factory WallSearchPostHit.fromJson(Map<String, dynamic> json) =>
      WallSearchPostHit(
        post: WallPost.fromJson(json['post'] as Map<String, dynamic>? ?? {}),
        excerpt: json['excerpt'] as String? ?? '',
        matchIn: json['match_in'] as String? ?? '',
      );

  @override
  List<Object?> get props => [post.id, excerpt];
}

class WallSearchCommentHit extends Equatable {
  const WallSearchCommentHit({
    required this.postId,
    this.postAuthorName,
    required this.comment,
    required this.excerpt,
  });

  final String postId;
  final String? postAuthorName;
  final WallComment comment;
  final String excerpt;

  factory WallSearchCommentHit.fromJson(Map<String, dynamic> json) =>
      WallSearchCommentHit(
        postId: json['post_id'] as String? ?? '',
        postAuthorName: json['post_author_name'] as String?,
        comment:
            WallComment.fromJson(json['comment'] as Map<String, dynamic>? ?? {}),
        excerpt: json['excerpt'] as String? ?? '',
      );

  @override
  List<Object?> get props => [postId, comment.id];
}

class WallSearchResponse extends Equatable {
  const WallSearchResponse({
    this.posts = const [],
    this.comments = const [],
  });

  final List<WallSearchPostHit> posts;
  final List<WallSearchCommentHit> comments;

  factory WallSearchResponse.fromJson(Map<String, dynamic> json) =>
      WallSearchResponse(
        posts: (json['posts'] as List<dynamic>? ?? [])
            .map((e) => WallSearchPostHit.fromJson(e as Map<String, dynamic>))
            .toList(),
        comments: (json['comments'] as List<dynamic>? ?? [])
            .map(
              (e) => WallSearchCommentHit.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );

  @override
  List<Object?> get props => [posts, comments];
}
