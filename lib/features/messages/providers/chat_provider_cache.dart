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
        dms: sortDms(cached.dms),
        channels: sortChannels(cached.channels),
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
      // Cache no decrypted E2EE preview text. The encrypted metadata is kept
      // and a live sidebar refresh restores the preview after PIN unlock.
      final safeDms = sidebar.dms
          .map(
            (dm) => dm.lastMessageEncryptionVersion == 1
                ? dm.copyWith(lastMessageBody: 'Encrypted message')
                : dm,
          )
          .toList();
      await sidebarCache.write(
        userId,
        ChatSidebar(channels: sidebar.channels, dms: safeDms),
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

  /// Reads the newest page of [conversationId] straight off disk and paints it
  /// before any request is made. Returns true when the cache had something, so
  /// the caller can skip the spinner. [ChatFeed.hasMore] is set from what else
  /// is on disk, which is what lets an offline user keep scrolling back.
  Future<bool> hydrateFeedFromCache(String conversationId) async {
    if (conversationId.isEmpty) return false;
    // Don't overwrite an already-loaded feed (e.g. user switching back quickly).
    final existing = state.feeds[feedKey(conversationId)];
    if (existing != null && existing.fetchedAt > 0) return true;
    try {
      var messages = await messageStore.page(conversationId);
      if (messages.isEmpty) return false;
      final oldestMs = messageTimeMs(messages.first);
      final hasOlder = await messageStore.hasOlderThan(
        conversationId,
        oldestMs,
      );
      messages = await decryptIfNeeded(messages);
      unawaited(ref.read(attachmentIntakeProvider).onMessages(messages));
      setFeed(
        feedKey(conversationId),
        ChatFeed(
          messages: messages,
          fetchedAt: 0, // 0 = from cache, triggers background network refresh
          loading: false,
          hasMore: hasOlder,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pages backwards through the local history when the server cannot be
  /// reached (or was never asked). Returns false when disk has nothing more
  /// to give, so the caller can fall back to its own error handling.
  Future<bool> loadOlderFromDisk(String conversationId, String key) async {
    final feed = state.feeds[key];
    if (feed == null || feed.messages.isEmpty) return false;
    final older = await messageStore.page(
      conversationId,
      beforeMs: messageTimeMs(feed.messages.first),
    );
    final known = feed.messages.map((m) => m.id).toSet();
    final fresh = older.where((m) => !known.contains(m.id)).toList();
    if (fresh.isEmpty) {
      setFeed(key, feed.copyWith(loadingMore: false, hasMore: false));
      return true;
    }
    final decrypted = await decryptIfNeeded(fresh);
    setFeed(
      key,
      feed.copyWith(
        messages: [...decrypted, ...feed.messages],
        loadingMore: false,
      ),
    );
    return true;
  }

  /// Persists the confirmed messages for [conversationId] to local DB after a
  /// successful server load. Runs fire-and-forget (non-blocking).
  void persistFeedAsync(String conversationId, List<ChatMessage> messages) {
    messageStore.saveAll(messages).ignore();
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
