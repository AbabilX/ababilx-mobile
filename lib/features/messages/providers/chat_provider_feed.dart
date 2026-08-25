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
        unawaited(ref.read(attachmentIntakeProvider).onMessages(sorted));
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
    if (!feed.hasMore || feed.loadingMore) return;
    final canUseDisk = threadRootId == null;
    if (feed.nextCursor.isEmpty && !canUseDisk) return;
    setFeed(key, feed.copyWith(loadingMore: true));

    // No server cursor yet — this feed was painted from disk (offline open),
    // so page backwards through the local history instead of asking a server
    // we have not successfully talked to.
    if (feed.nextCursor.isEmpty) {
      final served = await (this as _ChatCacheMixin).loadOlderFromDisk(
        conversationId,
        key,
      );
      if (!served) {
        setFeed(key, feed.copyWith(loadingMore: false, hasMore: false));
      }
      return;
    }

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
      if (threadRootId == null) {
        (this as _ChatCacheMixin).persistFeedAsync(conversationId, sorted);
      }
    } catch (_) {
      // Network gone mid-scroll: serve the older page from disk so the user
      // keeps reading instead of hitting a dead end.
      if (canUseDisk &&
          await (this as _ChatCacheMixin).loadOlderFromDisk(
            conversationId,
            key,
          )) {
        return;
      }
      setFeed(key, feed.copyWith(loadingMore: false));
    }
  }
}
