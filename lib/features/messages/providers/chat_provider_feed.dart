part of 'chat_provider.dart';

mixin _ChatFeedMixin on Notifier<ChatState> {
  ChatRepository get repo;

  void setFeed(String key, ChatFeed feed) {
    state = state.copyWith(feeds: {...state.feeds, key: feed});
  }

  Future<void> loadFeed(
    String conversationId, {
    String? threadRootId,
    bool force = false,
  }) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final existing = state.feeds[key] ?? const ChatFeed();
    final hasMessages = existing.messages.isNotEmpty;
    final stale = existing.fetchedAt == 0 ||
        DateTime.now().millisecondsSinceEpoch - existing.fetchedAt >
            feedStaleMs;
    if (!force && hasMessages && !stale) return;
    if (!hasMessages) setFeed(key, existing.copyWith(loading: true));
    try {
      final page = await repo.listMessages(
        conversationId,
        limit: threadRootId != null ? 100 : 50,
        thread: threadRootId,
      );
      final sorted =
          threadRootId != null ? page.messages : page.messages.reversed.toList();
      setFeed(
        key,
        ChatFeed(
          messages: sorted,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (threadRootId != null) {
        final replies =
            sorted.where((m) => m.id != threadRootId).toList(growable: false);
        state = state.copyWith(
          threadRepliesByRoot: {
            ...state.threadRepliesByRoot,
            threadRootId: replies,
          },
        );
      }
    } catch (_) {
      setFeed(key, (state.feeds[key] ?? const ChatFeed()).copyWith(loading: false));
    }
  }

  Future<void> loadMoreFeed(
    String conversationId, {
    String? threadRootId,
  }) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key] ?? const ChatFeed();
    if (!feed.hasMore || feed.nextCursor.isEmpty || feed.loadingMore) return;
    setFeed(key, feed.copyWith(loadingMore: true));
    try {
      final page = await repo.listMessages(
        conversationId,
        cursor: feed.nextCursor,
        limit: threadRootId != null ? 100 : 50,
        thread: threadRootId,
      );
      final sorted =
          threadRootId != null ? page.messages : page.messages.reversed.toList();
      setFeed(
        key,
        feed.copyWith(
          messages: [...sorted, ...feed.messages],
          loadingMore: false,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      setFeed(key, feed.copyWith(loadingMore: false));
    }
  }

  void appendFeedMessage(
    String conversationId,
    ChatMessage msg, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final existing = state.feeds[key];
    // Only update an already-loaded feed. If the feed has never been fetched,
    // skip — it will be loaded fresh (with full history) when the user opens
    // the conversation. Appending to an empty/unfetched feed would prevent the
    // full-history load from replacing it and leave the feed with only 1 msg.
    if (existing == null || existing.fetchedAt == 0) return;
    if (existing.messages.any((m) => m.id == msg.id)) return;
    setFeed(
      key,
      existing.copyWith(
        messages: [...existing.messages, msg],
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void updateFeedMessage(
    String conversationId,
    ChatMessage msg, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.map((m) => m.id == msg.id ? msg : m).toList(),
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void removeFeedMessage(
    String conversationId,
    String messageId, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.where((m) => m.id != messageId).toList(),
      ),
    );
  }

  void updateFeedReactions(
    String conversationId,
    String messageId,
    List<ChatReactionGroup> reactions, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages
            .map((m) =>
                m.id == messageId ? m.copyWith(reactions: reactions) : m)
            .toList(),
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
