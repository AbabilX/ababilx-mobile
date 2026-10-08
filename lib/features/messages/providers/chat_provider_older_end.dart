part of 'chat_provider.dart';

/// The first message of a conversation: where scrollback stops for good.
mixin _ChatOlderEndMixin
    on
        Notifier<ChatState>,
        _ChatFeedMixin,
        _ChatCacheMixin,
        _ChatOlderDiskMixin,
        _ChatOlderTopMixin,
        _ChatOlderServerMixin,
        _ChatOlderRefreshMixin,
        _ChatOlderEdgeMixin {
  /// The store has nothing older and a stretch says the server had nothing
  /// older either. Believed once the server has said so in this session: a
  /// stretch that outlived the rows it vouched for would otherwise end the
  /// history early, for good.
  Future<void> confirmEnd(String conversationId, String key) async {
    final feed = state.feeds[key];
    // Asked from the second-oldest message when there is one: an answer
    // holding the oldest proves the cursor was good, in a single request.
    // From the oldest itself, "nothing older" and "id unknown" look the same.
    final found = olderAnchors(feed?.messages ?? const [], limit: 3);
    final anchors = [...found.skip(1), ...found.take(1)];
    if (feed == null ||
        anchors.isEmpty ||
        feed.fetchedAt == 0 ||
        endConfirmed.contains(conversationId)) {
      return _stopLoadingMore(key, hasMore: false);
    }
    _showWaiting(key);
    try {
      final bottomMs = messageTimeMs(feed.messages.first);
      final known = feed.messages.map((m) => m.id).toSet();
      for (final anchor in anchors) {
        final page = await repo
            .listMessages(
              conversationId,
              cursor: anchor.id,
              limit: diskPageSize,
            )
            .timeout(olderPageTimeout);
        if (isDisposed) return;
        if (page.messages.isEmpty) continue;
        // A row whose content retention already blanked is not history the
        // phone is missing.
        final missing = page.messages.any(
          (m) =>
              !m.contentPurged &&
              !known.contains(m.id) &&
              messageTimeMs(m) < bottomMs,
        );
        if (!missing) break;
        await spanStore.forget(conversationId);
        walkCursor[key] = anchor.id;
        _stopLoadingMore(key, hasMore: true);
        return walkUnproven(conversationId, key);
      }
      endConfirmed.add(conversationId);
      _stopLoadingMore(key, hasMore: false);
    } catch (_) {
      _stopLoadingMore(key, hasMore: false);
    }
  }
}
