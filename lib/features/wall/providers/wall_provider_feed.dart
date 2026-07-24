part of 'wall_provider.dart';

mixin _WallFeedMixin on Notifier<WallState> {
  WallRepository get repo;

  Future<void> refreshMeta() async {
    try {
      final cats = await repo.listCategories();
      final stats = await repo.stats();
      state = state.copyWith(categories: cats, stats: stats);
    } catch (_) {}
  }

  Future<void> loadInitial({WallFeedFilter? filter}) async {
    final f = filter ?? state.filter;
    state = state.copyWith(
      filter: f,
      loading: true,
      clearError: true,
      posts: const [],
      nextCursor: '',
      hasMore: false,
    );
    try {
      final page = await _fetchPage(f);
      state = state.copyWith(
        posts: page.posts,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _fetchPage(state.filter, cursor: state.nextCursor);
      state = state.copyWith(
        posts: [...state.posts, ...page.posts],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> setFilter(WallFeedFilter filter) => loadInitial(filter: filter);

  Future<WallPostsPage> _fetchPage(
    WallFeedFilter f, {
    String? cursor,
  }) {
    return repo.listPosts(
      cursor: cursor,
      category: f.kind == WallFeedKind.category ? f.category : null,
      saved: f.kind == WallFeedKind.saved,
      mine: f.kind == WallFeedKind.mine,
    );
  }

  void _patchPost(String postId, WallPost Function(WallPost) fn) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id == postId) fn(p) else p,
      ],
    );
  }

  void prependPost(WallPost post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  void removePostLocal(String postId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }
}
