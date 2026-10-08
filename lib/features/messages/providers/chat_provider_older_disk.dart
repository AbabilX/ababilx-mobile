part of 'chat_provider.dart';

/// What one read of the local store put on screen.
typedef _DiskOlder = ({int added, bool exhausted});

/// Scrollback out of the phone's own store — no request, so it is as fast as
/// a query and works with no network at all.
mixin _ChatOlderDiskMixin
    on Notifier<ChatState>, _ChatFeedMixin, _ChatCacheMixin {
  int _diskPageFor(String? threadRootId) =>
      threadRootId == null ? diskPageSize : _ChatCacheMixin._threadDiskPage;

  /// Shows the page stored before the oldest message on screen.
  ///
  /// [floorMs] is how far back the caller trusts the store: rows older than
  /// it are left alone, because nothing has proven there is no gap between
  /// them and what is shown — see [FeedSpan]. `exhausted` is true when this
  /// read reached that floor or the end of the store, so the next page has to
  /// come from somewhere else.
  Future<_DiskOlder> showOlderFromDisk(
    String conversationId,
    String key, {
    String? threadRootId,
    int floorMs = 0,
  }) async {
    final feed = state.feeds[key];
    if (feed == null || feed.messages.isEmpty) {
      return (added: 0, exhausted: true);
    }
    final clock = ChatOlderTrace.start();
    final limit = _diskPageFor(threadRootId);
    final oldest = feed.messages.first;
    final older = await messageStore.page(
      conversationId,
      limit: limit,
      beforeMs: messageTimeMs(oldest),
      beforeId: oldest.id,
      threadRootId: threadRootId,
    );
    final inReach = older.where((m) => messageTimeMs(m) >= floorMs).toList();
    final exhausted = older.length < limit || inReach.length < older.length;
    final known = feed.messages.map((m) => m.id).toSet();
    final fresh = inReach
        .where((m) => !known.contains(m.id) && m.id != threadRootId)
        .toList();
    if (fresh.isEmpty || isDisposed) return (added: 0, exhausted: exhausted);
    final decrypted = await decryptIfNeeded(fresh);
    await warmMediaFrames(decrypted);
    if (isDisposed) return (added: 0, exhausted: exhausted);
    final latest = state.feeds[key] ?? feed;
    setFeed(
      key,
      latest.copyWith(
        messages: canonicalChatMessages([...decrypted, ...latest.messages]),
        loadingMore: false,
        hasMore: true,
      ),
    );
    if (threadRootId != null) syncThreadSummary(threadRootId, decrypted);
    ChatOlderTrace.end(clock, key, 'store', fresh.length);
    return (added: fresh.length, exhausted: exhausted);
  }

  /// Pages backwards through the local history when the server cannot be
  /// reached (or was never asked), with no floor: offline, what the phone
  /// holds is the whole answer. Returns false when there is no feed to page.
  Future<bool> loadOlderFromDisk(
    String conversationId,
    String key, {
    String? threadRootId,
  }) async {
    final feed = state.feeds[key];
    if (feed == null || feed.messages.isEmpty) return false;
    final shown = await showOlderFromDisk(
      conversationId,
      key,
      threadRootId: threadRootId,
    );
    if (isDisposed) return true;
    final latest = state.feeds[key];
    if (latest == null) return true;
    // A short page means the disk ran out; a full one may have more. A page
    // that added nothing is the end as well, or the caller would ask forever.
    setFeed(
      key,
      latest.copyWith(
        loadingMore: false,
        hasMore: shown.added > 0 && !shown.exhausted,
      ),
    );
    return true;
  }

  /// A server page without the rows whose content this phone still holds
  /// and the server has let go.
  ///
  /// At the end of its retention the server blanks a message and keeps the
  /// row, so a page can carry an empty copy of something the phone has in
  /// full. The phone is the archive: storing or drawing that copy would
  /// erase the only one left. A blank row the phone never had is kept — it
  /// is all there is to show.
  Future<List<ChatMessage>> keepingStoredContent(
    List<ChatMessage> fromServer,
  ) async {
    if (!fromServer.any((m) => m.contentPurged)) return fromServer;
    final kept = <ChatMessage>[];
    for (final message in fromServer) {
      if (message.contentPurged) {
        final held = await messageStore.byId(message.id);
        if (held != null && !held.contentPurged) continue;
      }
      kept.add(message);
    }
    return kept;
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
}
