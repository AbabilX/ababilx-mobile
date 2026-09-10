part of 'chat_provider.dart';

mixin _ChatFeedMixin on Notifier<ChatState> {
  ChatRepository get repo;

  /// See [ChatNotifier.isDisposed] — guards every write that follows an await.
  bool get isDisposed;

  void setFeed(String key, ChatFeed feed) {
    if (isDisposed) return;
    if (ref.read(messageVaultProvider).isStartingNewChat) {
      feed = feed.copyWith(messages: const [], hasMore: false);
    }
    final filtered = ref
        .read(chatMessageStoreProvider)
        .deletions
        .filter(feed.messages);
    state = state.copyWith(
      feeds: {
        ...state.feeds,
        key: feed.copyWith(messages: filtered),
      },
    );
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
      final sorted = canonicalChatMessages(messages);
      unawaited(
        repo
            .acknowledgeMessages(
              'delivered',
              page.messages.map((message) => message.id).toList(),
            )
            .catchError((_) {}),
      );
      if (state.activeConversationId == conversationId) {
        unawaited(
          repo
              .acknowledgeMessages(
                'read',
                page.messages.map((message) => message.id).toList(),
              )
              .catchError((_) {}),
        );
      }
      // A websocket event can arrive while this request is in flight. Merge
      // against the latest state, not the stale snapshot from request start.
      final latest = state.feeds[key] ?? existing;
      final merged = canonicalChatMessages([...latest.messages, ...sorted]);
      await (this as _ChatCacheMixin).persistFeed(sorted);
      // A server page running out does NOT mean the conversation has no more
      // history. A webhook feed is trimmed to its newest few messages and the
      // device holds the archive; ask the local store before closing the
      // scrollback, or a feed would dead-end at whatever the server kept.
      // With no cursor left, loadMoreFeed pages from disk on its own.
      final hasMore =
          page.hasMore ||
          (threadRootId == null &&
              merged.isNotEmpty &&
              await (this as _ChatCacheMixin).hasOlderOnDisk(
                conversationId,
                merged.first,
              ));
      final freshFeed = ChatFeed(
        messages: merged,
        nextCursor: page.nextCursor,
        hasMore: hasMore,
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
        loading: false,
        error: '',
      );
      setFeed(key, freshFeed);
      if (threadRootId == null) {
        unawaited(ref.read(attachmentIntakeProvider).onMessages(sorted));
      }
      if (threadRootId != null && !isDisposed) {
        final replies = sorted
            .where((m) => m.id != threadRootId)
            .toList(growable: false);
        state = state.copyWith(
          threadRepliesByRoot: {
            ...state.threadRepliesByRoot,
            threadRootId: replies,
          },
        );
      } else if (!isDisposed) {
        (this as _ChatThreadPrefetchMixin).prefetchThreadSummaries(
          conversationId,
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
      final sorted = canonicalChatMessages(messages);
      unawaited(
        repo
            .acknowledgeMessages(
              'delivered',
              page.messages.map((message) => message.id).toList(),
            )
            .catchError((_) {}),
      );
      if (state.activeConversationId == conversationId) {
        unawaited(
          repo
              .acknowledgeMessages(
                'read',
                page.messages.map((message) => message.id).toList(),
              )
              .catchError((_) {}),
        );
      }
      final latest = state.feeds[key] ?? feed;
      final merged = canonicalChatMessages([...latest.messages, ...sorted]);
      await (this as _ChatCacheMixin).persistFeed(sorted);
      setFeed(
        key,
        latest.copyWith(
          messages: merged,
          loadingMore: false,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
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
