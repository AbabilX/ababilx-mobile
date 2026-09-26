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

  /// Live copies received for feeds that are not open yet.
  final receivedBuffer = ReceivedMessageBuffer();

  /// One network refresh per feed at a time. The timeline, the resync and a
  /// retry can all ask at once; the second caller waits on the first.
  final _networkLoads = <String, Future<void>>{};

  /// Opens a feed: the disk page and the network refresh start together, and
  /// neither waits on the other. Whichever lands merges into the LATEST
  /// state, so a socket message, a deletion or the other half's result that
  /// arrived meanwhile is never overwritten by a stale snapshot.
  Future<void> loadFeed(
    String conversationId, {
    String? threadRootId,
    bool force = false,
  }) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final cache = this as _ChatCacheMixin;
    final hydration = cache.hydrateFeedFromCache(
      conversationId,
      threadRootId: threadRootId,
    );
    if (!force) {
      await hydration;
      final existing = state.feeds[key] ?? const ChatFeed();
      final stale =
          existing.fetchedAt == 0 ||
          DateTime.now().millisecondsSinceEpoch - existing.fetchedAt >
              feedStaleMs;
      if (existing.messages.isNotEmpty && !stale) return;
    }
    await (_networkLoads[key] ??=
        _refreshFeed(conversationId, threadRootId, hydration).whenComplete(() {
          _networkLoads.remove(key);
        }));
  }

  Future<void> _refreshFeed(
    String conversationId,
    String? threadRootId,
    Future<bool> hydration,
  ) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final cache = this as _ChatCacheMixin;
    final current = state.feeds[key] ?? const ChatFeed();
    if (current.messages.isEmpty) {
      setFeed(key, current.copyWith(loading: true, error: ''));
    }

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
      _acknowledge(conversationId, page.messages);
      await cache.stageFeedPage(sorted);
      unawaited((this as _ChatPrivateMixin).takePrivateCustody(sorted));
      // The disk half may still be reading; its page is older than this one
      // or equal to it, and merging after it keeps both.
      await hydration;
      if (isDisposed) return;
      final latest = state.feeds[key] ?? const ChatFeed();
      final merged = canonicalChatMessages([...latest.messages, ...sorted]);
      // A server page running out does NOT mean the conversation has no more
      // history. A webhook feed is trimmed to its newest few messages and the
      // device holds the archive; ask the local store before closing the
      // scrollback, or a feed would dead-end at whatever the server kept.
      // With no cursor left, loadMoreFeed pages from disk on its own.
      final hasMore =
          page.hasMore ||
          (threadRootId == null &&
              merged.isNotEmpty &&
              await cache.hasOlderOnDisk(conversationId, merged.first));
      if (isDisposed) return;
      final after = state.feeds[key] ?? latest;
      setFeed(
        key,
        after.copyWith(
          messages: canonicalChatMessages([...after.messages, ...sorted]),
          nextCursor: page.nextCursor,
          hasMore: hasMore,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
          loading: false,
          error: '',
        ),
      );
      // Only still open when the disk had nothing: then this is the paint.
      ChatOpenTrace.mark(key, 'network');
      ChatOpenTrace.painted(key, sorted.length);
      if (threadRootId == null) {
        unawaited(ref.read(attachmentIntakeProvider).onMessages(sorted));
        if (!isDisposed) {
          (this as _ChatThreadPrefetchMixin).prefetchThreadSummaries(
            conversationId,
          );
        }
      } else {
        cache.syncThreadSummary(threadRootId, sorted);
      }
    } catch (_) {
      // Whatever the disk had is the answer now; wait for it before deciding
      // between "keep showing the cache" and "say we are offline".
      try {
        await hydration;
      } catch (_) {}
      if (isDisposed) return;
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

  void _acknowledge(String conversationId, List<ChatMessage> messages) {
    final ids = messages.map((message) => message.id).toList();
    if (ids.isEmpty) return;
    unawaited(repo.acknowledgeMessages('delivered', ids).catchError((_) {}));
    if (state.activeConversationId == conversationId) {
      unawaited(repo.acknowledgeMessages('read', ids).catchError((_) {}));
    }
  }

  Future<void> loadMoreFeed(
    String conversationId, {
    String? threadRootId,
  }) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key] ?? const ChatFeed();
    if (!feed.hasMore || feed.loadingMore) return;
    final cache = this as _ChatCacheMixin;
    setFeed(key, feed.copyWith(loadingMore: true));

    // No server cursor yet — this feed was painted from disk (offline open),
    // so page backwards through the local history instead of asking a server
    // we have not successfully talked to. Threads included: their replies
    // are on disk under the root, same as the main feed's messages.
    if (feed.nextCursor.isEmpty) {
      final served = await cache.loadOlderFromDisk(
        conversationId,
        key,
        threadRootId: threadRootId,
      );
      if (!served) _stopLoadingMore(key, hasMore: false);
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
      _acknowledge(conversationId, page.messages);
      await cache.stageFeedPage(sorted);
      unawaited((this as _ChatPrivateMixin).takePrivateCustody(sorted));
      if (isDisposed) return;
      final latest = state.feeds[key] ?? feed;
      final merged = canonicalChatMessages([...latest.messages, ...sorted]);
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
      if (threadRootId != null) cache.syncThreadSummary(threadRootId, sorted);
    } catch (_) {
      // Network gone mid-scroll: serve the older page from disk so the user
      // keeps reading instead of hitting a dead end.
      if (await cache.loadOlderFromDisk(
        conversationId,
        key,
        threadRootId: threadRootId,
      )) {
        return;
      }
      _stopLoadingMore(key);
    }
  }

  void _stopLoadingMore(String key, {bool? hasMore}) {
    final latest = state.feeds[key];
    if (latest == null) return;
    setFeed(key, latest.copyWith(loadingMore: false, hasMore: hasMore));
  }
}
