part of 'chat_provider.dart';

/// Cache hydrate / persist for sidebar + message feeds (WhatsApp-style instant load).
mixin _ChatCacheMixin on Notifier<ChatState>, _ChatFeedMixin {
  ChatSidebarCache get sidebarCache;
  ChatFeedCache get feedCache;

  // ─── Sidebar cache ──────────────────────────────────────────────────────────

  Future<bool> hydrateSidebarFromCache() async {
    final userId = state.currentUserId;
    if (userId.isEmpty) return false;
    try {
      final cached = await sidebarCache.read(userId);
      if (cached == null) return false;
      if (cached.dms.isEmpty && cached.channels.isEmpty) return false;
      state = state.copyWith(
        dms: sortDms(cached.dms),
        channels: sortChannels(cached.channels),
        sidebarLoading: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> persistSidebar(ChatSidebar sidebar) async {
    final userId = state.currentUserId;
    if (userId.isEmpty) return;
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
    } catch (_) {}
  }

  Future<void> clearSidebarCache() async {
    try {
      await sidebarCache.clearAll();
    } catch (_) {}
  }

  // ─── Feed cache ─────────────────────────────────────────────────────────────

  /// Reads cached messages for [conversationId] and injects them into the feed
  /// map immediately. Returns true if cache had data (avoids showing spinner).
  Future<bool> hydrateFeedFromCache(String conversationId) async {
    if (conversationId.isEmpty) return false;
    // Don't overwrite an already-loaded feed (e.g. user switching back quickly).
    final existing = state.feeds[feedKey(conversationId)];
    if (existing != null && existing.fetchedAt > 0) return true;
    try {
      var messages = await feedCache.read(conversationId);
      if (messages == null || messages.isEmpty) return false;
      if (state.conversationById(conversationId)?.isDm == true) {
        messages = await ref
            .read(messageVaultProvider)
            .decryptMessages(messages, state.currentUserId);
      }
      setFeed(
        feedKey(conversationId),
        ChatFeed(
          messages: messages,
          fetchedAt: 0, // 0 = from cache, triggers background network refresh
          loading: false,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Persists the confirmed messages for [conversationId] to local DB after a
  /// successful server load. Runs fire-and-forget (non-blocking).
  void persistFeedAsync(String conversationId, List<ChatMessage> messages) {
    feedCache.write(conversationId, messages).ignore();
  }
}
