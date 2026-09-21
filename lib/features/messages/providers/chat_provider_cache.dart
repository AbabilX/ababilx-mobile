part of 'chat_provider.dart';

/// Cache hydrate / persist for the sidebar and the durable message history —
/// both painted from disk before any request, so a cold offline open still
/// shows the last known chat list and full readable history.
mixin _ChatCacheMixin on Notifier<ChatState>, _ChatFeedMixin {
  ChatSidebarCache get sidebarCache;
  ChatMessageStore get messageStore;

  // ─── Sidebar cache ──────────────────────────────────────────────────────────

  Future<bool> hydrateSidebarFromCache() async {
    var userId = state.currentUserId;
    if (userId.isEmpty) {
      try {
        userId = await (this as ChatNotifier).localUserId();
      } catch (e) {
        debugPrint(
          '[ChatCache] hydrateSidebarFromCache: localUserId threw: $e',
        );
      }
    }
    if (userId.isEmpty) {
      debugPrint(
        '[ChatCache] hydrateSidebarFromCache: no local userId, aborting',
      );
      return false;
    }
    try {
      final cached = await sidebarCache.read(userId);
      if (cached == null) return false;
      if (cached.dms.isEmpty && cached.channels.isEmpty) {
        debugPrint('[ChatCache] hydrateSidebarFromCache: cached row is empty');
        return false;
      }
      state = state.copyWith(
        dms: sortDms(
          cached.dms.map((this as ChatNotifier).visiblePreview).toList(),
        ),
        channels: sortChannels(
          cached.channels.map((this as ChatNotifier).visiblePreview).toList(),
        ),
        sidebarLoading: false,
      );
      return true;
    } catch (e) {
      debugPrint('[ChatCache] hydrateSidebarFromCache: read threw: $e');
      return false;
    }
  }

  Future<void> persistSidebar(ChatSidebar sidebar) async {
    final userId = state.currentUserId;
    if (userId.isEmpty) {
      debugPrint(
        '[ChatCache] persistSidebar: currentUserId empty, not writing',
      );
      return;
    }
    try {
      // No sealed preview text on disk, from a DM or a group. The ciphertext
      // beside it is kept, and `openCachedPreviews` reopens it on the next
      // launch — offline included.
      await sidebarCache.write(
        userId,
        ChatSidebar(
          channels: sidebar.channels.map(previewForDisk).toList(),
          dms: sidebar.dms.map(previewForDisk).toList(),
        ),
      );
    } catch (e) {
      debugPrint('[ChatCache] persistSidebar: write threw: $e');
    }
  }

  Future<void> clearSidebarCache() async {
    try {
      await sidebarCache.clearAll();
    } catch (_) {}
  }

  // ─── Message history (durable — see CachedMessages) ───────────────────────

  /// One disk read per feed at a time — the timeline, a retry and the
  /// network half of [loadFeed] all ask for it.
  final _hydrations = <String, Future<bool>>{};

  /// Feeds whose newest disk page is already in memory this session. After
  /// that, memory is kept in step by every write path, so reading the same
  /// page again on each open would only cost a query and a decrypt.
  final _diskHydrated = <String>{};

  /// How many replies a thread reads per disk page — the network's own
  /// thread page size, so the two halves agree on what "a page" is.
  static const _threadDiskPage = 100;

  /// Reads the newest page of a feed straight off disk and paints it before
  /// any request is made. Returns true when there is something to show, so
  /// the caller can skip the spinner. [ChatFeed.hasMore] is set from what else
  /// is on disk, which is what lets an offline user keep scrolling back.
  ///
  /// Threads read their replies the same way: they are stored under the
  /// root, so a thread opens offline exactly like the conversation does.
  Future<bool> hydrateFeedFromCache(
    String conversationId, {
    String? threadRootId,
  }) {
    if (conversationId.isEmpty) return Future.value(false);
    final key = feedKey(conversationId, threadRootId: threadRootId);
    return _hydrations[key] ??= _hydrate(conversationId, threadRootId)
        .whenComplete(() {
          // A block body on purpose: `=> remove(key)` would return this very
          // future to whenComplete, which then waits on itself forever.
          _hydrations.remove(key);
        });
  }

  Future<bool> _hydrate(String conversationId, String? threadRootId) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    // Live copies first, synchronously: they are already decrypted, so the
    // open shows them on its first frame whatever the disk is doing.
    _absorbReceived(key, threadRootId);
    final existing = state.feeds[key];
    if (existing != null &&
        (existing.fetchedAt > 0 || _diskHydrated.contains(key))) {
      ChatOpenTrace.painted(key, existing.messages.length);
      return existing.messages.isNotEmpty;
    }
    try {
      var messages = await messageStore.page(
        conversationId,
        limit: threadRootId == null ? diskPageSize : _threadDiskPage,
        threadRootId: threadRootId,
      );
      ChatOpenTrace.mark(key, 'disk');
      if (threadRootId != null) {
        messages = messages.where((m) => m.id != threadRootId).toList();
      }
      final hasOlder =
          messages.isNotEmpty &&
          await hasOlderOnDisk(
            conversationId,
            messages.first,
            threadRootId: threadRootId,
          );
      messages = await decryptIfNeeded(messages);
      ChatOpenTrace.mark(key, 'decrypt');
      await warmMediaFrames(messages);
      ChatOpenTrace.mark(key, 'frames');
      if (isDisposed) return false;
      _diskHydrated.add(key);
      // Merge into what is in memory NOW: a socket message, a deletion or a
      // network page may have landed while the disk was being read.
      final latest = state.feeds[key];
      final merged = canonicalChatMessages([
        ...messages,
        ...receivedBuffer.take(key),
        ...?latest?.messages,
        if (threadRootId != null) ...?state.threadRepliesByRoot[threadRootId],
      ]);
      if (merged.isEmpty) return false;
      unawaited(ref.read(attachmentIntakeProvider).onMessages(merged));
      final fromNetwork = latest != null && latest.fetchedAt > 0;
      setFeed(
        key,
        (latest ?? const ChatFeed()).copyWith(
          messages: merged,
          loading: false,
          error: '',
          // A network page decided its own scrollback; before one lands, the
          // disk is the only thing that knows whether there is more.
          hasMore: fromNetwork ? latest.hasMore : hasOlder,
        ),
      );
      if (threadRootId != null) syncThreadSummary(threadRootId, merged);
      ChatOpenTrace.painted(key, merged.length);
      return true;
    } catch (_) {
      return state.feeds[key]?.messages.isNotEmpty ?? false;
    }
  }

  /// Moves the buffered live copies into their feed, creating it when there
  /// is none yet. After this the feed owns them — see [ReceivedMessageBuffer].
  void _absorbReceived(String key, String? threadRootId) {
    final received = receivedBuffer.take(key);
    if (received.isEmpty) return;
    final latest = state.feeds[key] ?? const ChatFeed();
    setFeed(
      key,
      latest.copyWith(
        messages: canonicalChatMessages([...latest.messages, ...received]),
      ),
    );
    if (threadRootId != null) syncThreadSummary(threadRootId, received);
  }

  /// Keeps the gray last-reply line under a root in step with the thread
  /// itself: every reply the thread feed learns about, the summary learns too.
  void syncThreadSummary(String rootId, Iterable<ChatMessage> replies) {
    if (isDisposed) return;
    final incoming = replies.where((m) => m.id != rootId).toList();
    if (incoming.isEmpty) return;
    final current = state.threadRepliesByRoot[rootId] ?? const [];
    final merged = messageStore.deletions.filter(
      canonicalChatMessages([...current, ...incoming]),
    );
    state = state.copyWith(
      threadRepliesByRoot: {...state.threadRepliesByRoot, rootId: merged},
    );
  }

  /// Pages backwards through the local history when the server cannot be
  /// reached (or was never asked). Returns false when disk has nothing more
  /// to give, so the caller can fall back to its own error handling.
  Future<bool> loadOlderFromDisk(
    String conversationId,
    String key, {
    String? threadRootId,
  }) async {
    final feed = state.feeds[key];
    if (feed == null || feed.messages.isEmpty) return false;
    final oldest = feed.messages.first;
    final older = await messageStore.page(
      conversationId,
      limit: threadRootId == null ? diskPageSize : _threadDiskPage,
      beforeMs: messageTimeMs(oldest),
      beforeId: oldest.id,
      threadRootId: threadRootId,
    );
    final known = feed.messages.map((m) => m.id).toSet();
    final fresh = older
        .where((m) => !known.contains(m.id) && m.id != threadRootId)
        .toList();
    if (isDisposed) return true;
    if (fresh.isEmpty) {
      final latest = state.feeds[key] ?? feed;
      setFeed(key, latest.copyWith(loadingMore: false, hasMore: false));
      return true;
    }
    final decrypted = await decryptIfNeeded(fresh);
    await warmMediaFrames(decrypted);
    if (isDisposed) return true;
    final latest = state.feeds[key] ?? feed;
    setFeed(
      key,
      latest.copyWith(
        messages: canonicalChatMessages([...decrypted, ...latest.messages]),
        loadingMore: false,
        // A short page means the disk ran out; a full one may have more.
        hasMore:
            older.length >=
            (threadRootId == null ? diskPageSize : _threadDiskPage),
      ),
    );
    if (threadRootId != null) syncThreadSummary(threadRootId, decrypted);
    return true;
  }

  /// Whether the local store holds anything older than [oldest].
  ///
  /// The server is not the whole history any more. A webhook feed keeps only
  /// its newest few messages server-side and the device is the archive, and a
  /// free workspace's files age out the same way — so `has_more: false` means
  /// "the server has no more", never "there is no more".
  Future<bool> hasOlderOnDisk(
    String conversationId,
    ChatMessage oldest, {
    String? threadRootId,
  }) async {
    if (threadRootId == null) {
      return messageStore.hasOlderThan(
        conversationId,
        messageTimeMs(oldest),
        beforeId: oldest.id,
      );
    }
    // The store's EXISTS check covers top-level rows only; a one-row page
    // under the root answers the same question for a thread.
    final older = await messageStore.page(
      conversationId,
      limit: 1,
      beforeMs: messageTimeMs(oldest),
      beforeId: oldest.id,
      threadRootId: threadRootId,
    );
    return older.isNotEmpty;
  }

  /// A page restored from the server's history, while its conversation may
  /// be on screen. It is merged only where it touches what is shown — the
  /// newest end of a long history — so a restore never pulls a whole archive
  /// into memory; anything older stays on disk and is reached by scrolling.
  void mergeRestoredPage(
    String conversationId,
    List<ChatMessage> messages, {
    String? threadRootId,
  }) {
    if (isDisposed || messages.isEmpty) return;
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final latest = state.feeds[key];
    if (latest == null) return;
    final shownFrom = latest.messages.isEmpty
        ? 0
        : messageTimeMs(latest.messages.first);
    final touching = messages
        .where((m) => messageTimeMs(m) >= shownFrom)
        .toList();
    final olderExists = touching.length < messages.length;
    if (touching.isEmpty && !olderExists) return;
    setFeed(
      key,
      latest.copyWith(
        messages: canonicalChatMessages([...latest.messages, ...touching]),
        hasMore: latest.hasMore || olderExists,
      ),
    );
    if (threadRootId != null) syncThreadSummary(threadRootId, touching);
  }

  /// Forgets which feeds were read from disk — the feeds themselves are being
  /// dropped (history reset, account switch), so the next open reads again.
  void resetFeedHydration() {
    _diskHydrated.clear();
    receivedBuffer.clear();
  }

  /// Persists a network page before it becomes the canonical in-memory feed.
  Future<void> persistFeed(List<ChatMessage> messages) =>
      messageStore.saveAll(messages);

  /// A network page on its way into the feed: persisted, and its photo and
  /// video sizes loaded so its rows mount at their final height.
  Future<void> stageFeedPage(List<ChatMessage> messages) async {
    await persistFeed(messages);
    await warmMediaFrames(messages);
  }

  /// Recorded media sizes for [messages], into the attachment memory, before
  /// a row mounts — see `MediaFrameLock`. Bounded: a slow disk only costs the
  /// default frame, never a late feed.
  Future<void> warmMediaFrames(List<ChatMessage> messages) async {
    try {
      await ref
          .read(attachmentDimensionReaderProvider)
          .warm(messages.expand((m) => m.attachments))
          .timeout(const Duration(milliseconds: 250));
    } catch (_) {}
  }

  /// Persists a single message — the WS path, where re-writing the whole feed
  /// on every reaction would be wasted work.
  void persistMessageAsync(ChatMessage message) {
    messageStore.saveOne(message).ignore();
  }

  void deleteCachedMessageAsync(String messageId) {
    messageStore.remove(messageId).ignore();
    ref.read(attachmentSweeperProvider).onMessageDeleted(messageId).ignore();
  }
}
