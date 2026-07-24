import 'package:equatable/equatable.dart';

import 'wall_post.dart';

class WallPostsPage extends Equatable {
  const WallPostsPage({
    this.posts = const [],
    this.nextCursor = '',
    this.hasMore = false,
  });

  final List<WallPost> posts;
  final String nextCursor;
  final bool hasMore;

  factory WallPostsPage.fromJson(Map<String, dynamic> json) => WallPostsPage(
        posts: (json['posts'] as List<dynamic>? ?? [])
            .map((e) => WallPost.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['next_cursor'] as String? ?? '',
        hasMore: json['has_more'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [posts, nextCursor, hasMore];
}

class WallStats extends Equatable {
  const WallStats({
    this.totalPosts = 0,
    this.myPosts = 0,
    this.mySaves = 0,
    this.categoryCounts = const {},
  });

  final int totalPosts;
  final int myPosts;
  final int mySaves;
  final Map<String, int> categoryCounts;

  factory WallStats.fromJson(Map<String, dynamic> json) {
    final raw = json['category_counts'];
    final counts = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        counts[k.toString()] = (v is int) ? v : int.tryParse('$v') ?? 0;
      });
    }
    return WallStats(
      totalPosts: json['total_posts'] as int? ?? 0,
      myPosts: json['my_posts'] as int? ?? 0,
      mySaves: json['my_saves'] as int? ?? 0,
      categoryCounts: counts,
    );
  }

  @override
  List<Object?> get props => [totalPosts, myPosts, mySaves];
}
