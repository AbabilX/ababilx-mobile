import 'package:equatable/equatable.dart';

import '../data/models/wall_models.dart';

enum WallFeedKind { all, mine, saved, category }

class WallFeedFilter extends Equatable {
  const WallFeedFilter.all()
      : kind = WallFeedKind.all,
        category = null;

  const WallFeedFilter.mine()
      : kind = WallFeedKind.mine,
        category = null;

  const WallFeedFilter.saved()
      : kind = WallFeedKind.saved,
        category = null;

  const WallFeedFilter.category(this.category) : kind = WallFeedKind.category;

  final WallFeedKind kind;
  final String? category;

  @override
  List<Object?> get props => [kind, category];
}

class WallState extends Equatable {
  const WallState({
    this.posts = const [],
    this.filter = const WallFeedFilter.all(),
    this.nextCursor = '',
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.categories = const [],
    this.stats,
    this.currentUserId = '',
  });

  final List<WallPost> posts;
  final WallFeedFilter filter;
  final String nextCursor;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<WallCategory> categories;
  final WallStats? stats;
  final String currentUserId;

  WallState copyWith({
    List<WallPost>? posts,
    WallFeedFilter? filter,
    String? nextCursor,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    List<WallCategory>? categories,
    WallStats? stats,
    String? currentUserId,
  }) =>
      WallState(
        posts: posts ?? this.posts,
        filter: filter ?? this.filter,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        categories: categories ?? this.categories,
        stats: stats ?? this.stats,
        currentUserId: currentUserId ?? this.currentUserId,
      );

  @override
  List<Object?> get props => [
        posts,
        filter,
        nextCursor,
        hasMore,
        loading,
        loadingMore,
        error,
        categories,
        stats,
        currentUserId,
      ];
}
