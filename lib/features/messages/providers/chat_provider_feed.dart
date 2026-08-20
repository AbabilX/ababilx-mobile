part of 'chat_provider.dart';

mixin _ChatFeedMixin on Notifier<ChatState> {
  ChatRepository get repo;

  void setFeed(String key, ChatFeed feed) {
    state = state.copyWith(feeds: {...state.feeds, key: feed});
  }

  /// Decrypts when the page itself carries E2EE rows. Deciding this from the
  /// sidebar entry instead breaks the push-notification path: the conversation
  /// screen can mount before the sidebar exists, and the rows render blank.
  Future<List<ChatMessage>> decryptIfNeeded(List<ChatMessage> messages) async {
    if (!messages.any((m) => m.isEncrypted)) return messages;
    final currentUserId = await (this as ChatNotifier).ensureCurrentUserId();
    return ref
        .read(messageVaultProvider)
        .decryptMessages(messages, currentUserId);
  }

  Future<void> loadFeed(
    String conversationId, {
    String? threadRootId,
    bool force = false,
  }) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    var existing = state.feeds[key] ?? const ChatFeed();

    // Hydrate from SQLite cache first if this feed is not in memory yet
    if (existing.messages.isEmpty && threadRootId == null) {
      final hadCachedFeed = await (this as _ChatCacheMixin)
          .hydrateFeedFromCache(conversationId);
      if (hadCachedFeed) {
        existing = state.feeds[key] ?? existing;
      }
    }

    final hasMessages = existing.messages.isNotEmpty;
    final stale =
        existing.fetchedAt == 0 ||
        DateTime.now().millisecondsSinceEpoch - existing.fetchedAt >
            feedStaleMs;
    if (!force && hasMessages && !stale) return;
    if (!hasMessages) setFeed(key, existing.copyWith(loading: true, error: ''));

    try {
      final page = await repo
          .listMessages(
            conversationId,
            limit: threadRootId != null ? 100 : 50,
            thread: threadRootId,
          )
          .timeout(firstLoadNetworkTimeout);
      final messages = await decryptIfNeeded(page.messages);
      final sorted = threadRootId != null
          ? messages
          : messages.reversed.toList();
      final freshFeed = ChatFeed(
        messages: sorted,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
        loading: false,
        error: '',
      );
      setFeed(key, freshFeed);
      // Persist main conversation feed (not thread feeds) to local DB so the
      // next open is instant (cache-first load). Fire-and-forget.
      if (threadRootId == null) {
        (this as _ChatCacheMixin).persistFeedAsync(conversationId, sorted);
      }
      if (threadRootId != null) {
        final replies = sorted
            .where((m) => m.id != threadRootId)
            .toList(growable: false);
        state = state.copyWith(
          threadRepliesByRoot: {
            ...state.threadRepliesByRoot,
            threadRootId: replies,
          },
        );
      }
    } catch (_) {
      final currentFeed = state.feeds[key] ?? const ChatFeed();
      // If we have cached messages, keep them rendered without error banner
      if (currentFeed.messages.isNotEmpty) {
        setFeed(key, currentFeed.copyWith(loading: false, error: ''));
      } else {
        setFeed(
          key,
          currentFeed.copyWith(
            loading: false,
            error: 'Waiting for network connection...',
          ),
        );
      }
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
      final messages = await decryptIfNeeded(page.messages);
      final sorted = threadRootId != null
          ? messages
          : messages.reversed.toList();
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
            .map(
              (m) => m.id == messageId ? m.copyWith(reactions: reactions) : m,
            )
            .toList(),
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
