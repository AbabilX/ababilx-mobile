part of 'chat_provider.dart';

/// Scrollback past what the phone has proven it holds: the old end of a
/// stretch, history nothing vouches for, and the very first message.
///
/// Every path here ends one of three ways — rows on screen, `hasMore` false,
/// or the store read as a fallback — so a caller that asks again always
/// makes progress.
mixin _ChatOlderEdgeMixin
    on
        Notifier<ChatState>,
        _ChatFeedMixin,
        _ChatCacheMixin,
        _ChatOlderDiskMixin,
        _ChatOlderTopMixin,
        _ChatOlderServerMixin,
        _ChatOlderRefreshMixin {
  void _showWaiting(String key) {
    final feed = state.feeds[key];
    if (feed != null) setFeed(key, feed.copyWith(loadingMore: true));
  }

  /// Puts fetched [rows] on screen; returns how many were new to it.
  int _showOlderRows(String key, List<ChatMessage> rows) {
    final latest = state.feeds[key];
    if (latest == null) return 0;
    final known = latest.messages.map((m) => m.id).toSet();
    setFeed(
      key,
      latest.copyWith(
        messages: canonicalChatMessages([...latest.messages, ...rows]),
        loadingMore: false,
        hasMore: true,
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return rows.where((m) => !known.contains(m.id)).length;
  }

  /// The server could not be asked. What the phone holds is the answer until
  /// the next newest page lands — which is also what clears this.
  Future<void> _readStoreOnly(String conversationId, String key) async {
    serverSilent.add(conversationId);
    if (!await loadOlderFromDisk(conversationId, key)) _stopLoadingMore(key);
  }

  /// The reader reached the old end of [stretch]: the next page has to come
  /// from the server. It is stored, the stretch grows by what it proves, and
  /// the timeline then reads on from the store as it does everywhere else.
  Future<void> extendStretch(
    String conversationId,
    String key,
    FeedSpan stretch,
  ) async {
    final window = state.feeds[key]?.messages ?? const <ChatMessage>[];
    if (window.isEmpty) return;
    var cursor = stretch.cursor;
    var fromMs = stretch.lowMs;
    if (cursor.isEmpty || messageTimeMs(window.first) > fromMs) {
      // The store ran out short of where the stretch says it reaches, so it
      // lost rows the stretch vouched for. Trust ends at what is on screen.
      final anchor = olderAnchors(window, limit: 1).firstOrNull;
      if (anchor == null) return _readStoreOnly(conversationId, key);
      cursor = anchor.id;
      fromMs = messageTimeMs(anchor);
      await spanStore.update(
        conversationId,
        (current) => current.distrustBelow(fromMs, cursor: cursor),
      );
    }
    _showWaiting(key);
    olderAhead[conversationId] = 0;
    try {
      // A page can hold nothing but old thread roots, which are stored and
      // not shown; ask on rather than hand the reader an empty load.
      for (var round = 0; round < 3 && cursor.isNotEmpty; round++) {
        final answer = await pullOlderChecked(
          conversationId,
          cursor: cursor,
          fromMs: fromMs,
          window: state.feeds[key]?.messages ?? window,
        );
        if (isDisposed) return;
        final pull = answer.pull;
        if (!answer.canTell || pull == null) {
          return _readStoreOnly(conversationId, key);
        }
        final joined = await recordOlderPage(
          conversationId,
          pull,
          fromMs: answer.fromMs,
        );
        if (isDisposed) return;
        // Drawn from the store, not from the page: the page is in it now,
        // and so is anything stored earlier that belongs between its rows —
        // a thread root that arrived in a newer page, listed by its reply.
        final added = joined == null
            ? _showOlderRows(key, pull.messages)
            : (await showOlderFromDisk(
                conversationId,
                key,
                floorMs: joined.done ? 0 : joined.lowMs,
              )).added;
        if (isDisposed) return;
        if (added > 0 || joined == null || joined.done) break;
        cursor = joined.cursor;
        fromMs = joined.lowMs;
      }
      _stopLoadingMore(key);
      if (olderAhead.containsKey(conversationId)) {
        syncAhead(conversationId, key);
      }
    } catch (_) {
      await _readStoreOnly(conversationId, key);
    }
  }

  /// History nothing vouches for — a chat opened offline, or scrolled back
  /// before its newest page had arrived.
  ///
  /// The store is read first here too, so the reader never waits on it. The
  /// page is then checked against the server behind them, which is also what
  /// finds a message this phone never received. Only when the store runs out
  /// is the server asked for more, and no stretch is recorded for that: a
  /// walk started in the middle cannot prove what lies above it.
  Future<void> walkUnproven(String conversationId, String key) async {
    final feed = state.feeds[key];
    if (feed == null || feed.messages.isEmpty) return;
    // Never fetched this session means opened offline: asking would make
    // the reader wait out a timeout before every page of their own history.
    final online = feed.fetchedAt > 0;
    if (!walkCursor.containsKey(key)) {
      final anchor = olderAnchors(feed.messages, limit: 1).firstOrNull;
      final shown = await showOlderFromDisk(conversationId, key);
      if (isDisposed) return;
      if (shown.added > 0) {
        if (online && anchor != null) {
          refreshOlderShown(conversationId, anchor, always: true);
        }
        return;
      }
    }
    final window = state.feeds[key]?.messages ?? feed.messages;
    final cursor =
        walkCursor[key] ?? olderAnchors(window, limit: 1).firstOrNull?.id ?? '';
    if (!online || cursor.isEmpty) {
      return _stopLoadingMore(key, hasMore: false);
    }
    _showWaiting(key);
    try {
      final answer = await pullOlderChecked(
        conversationId,
        cursor: cursor,
        fromMs: 0,
        window: window,
      );
      if (isDisposed) return;
      final pull = answer.pull;
      if (pull == null || pull.page.messages.isEmpty) {
        return _readStoreOnly(conversationId, key);
      }
      _showOlderRows(key, pull.messages);
      if (pull.page.hasMore) {
        walkCursor[key] = pull.page.nextCursor;
      } else {
        // The server is out; anything older is on this phone alone.
        walkCursor.remove(key);
        serverSilent.add(conversationId);
      }
    } catch (_) {
      await _readStoreOnly(conversationId, key);
    }
  }
}
