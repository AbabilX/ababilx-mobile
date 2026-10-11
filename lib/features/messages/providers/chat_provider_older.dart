part of 'chat_provider.dart';

/// Scrolling back through a conversation.
///
/// ```
/// inside a proven stretch  -> the phone's own store, at once, no request
/// at its old end           -> the server, one page: stored, then shown
/// no network               -> the store, whatever it holds
/// ```
///
/// The store used to be the fallback and the server the source, so every
/// page of history the phone already held was downloaded again, decrypted
/// again and written again while the reader watched a spinner. Signal's
/// conversation reads its database and nothing else; this is the same,
/// with one thing Signal's protocol gives for free and ours does not: proof
/// that the store has no hole in it. That proof is a [FeedSpan].
mixin _ChatOlderMixin
    on
        Notifier<ChatState>,
        _ChatFeedMixin,
        _ChatCacheMixin,
        _ChatOlderDiskMixin,
        _ChatOlderTopMixin,
        _ChatOlderServerMixin,
        _ChatOlderRefreshMixin,
        _ChatOlderEdgeMixin,
        _ChatOlderEndMixin {
  final _olderLoads = <String, Future<void>>{};

  /// Loads the page before the oldest message shown. One load per feed at a
  /// time, and a second caller is handed the first one's future — so
  /// awaiting this always means "that page has landed", whoever started it.
  Future<void> loadMoreFeed(String conversationId, {String? threadRootId}) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final running = _olderLoads[key];
    if (running != null) return running;
    final feed = state.feeds[key];
    if (feed == null || !feed.hasMore || feed.messages.isEmpty) {
      return Future<void>.value();
    }
    return _olderLoads[key] = _loadOlder(conversationId, key, threadRootId)
        .whenComplete(() {
          // A block body: `=> remove(key)` would hand this future back to
          // whenComplete, which then waits on itself.
          _olderLoads.remove(key);
        });
  }

  Future<void> _loadOlder(
    String conversationId,
    String key,
    String? threadRootId,
  ) async {
    try {
      if (threadRootId != null) {
        await _loadOlderThread(conversationId, key, threadRootId);
      } else {
        await _loadOlderMain(conversationId, key);
      }
    } catch (_) {
      _stopLoadingMore(key);
    }
  }

  Future<void> _loadOlderMain(String conversationId, String key) async {
    pagedOlder.add(key);
    if (serverSilent.contains(conversationId)) {
      if (!await loadOlderFromDisk(conversationId, key)) _stopLoadingMore(key);
      return;
    }
    final bottomMs = messageTimeMs(state.feeds[key]!.messages.first);
    var stretch = (await spanStore.read(conversationId)).at(bottomMs);
    if (isDisposed) return;
    if (stretch == null) return walkUnproven(conversationId, key);
    if (await _showProven(conversationId, key, stretch)) return;
    if (stretch.done) return confirmEnd(conversationId, key);
    // The pages being fetched ahead may be the very ones wanted here.
    final ahead = _aheadRuns[conversationId];
    if (ahead != null) {
      _showWaiting(key);
      await ahead;
      if (isDisposed) return;
      stretch = (await spanStore.read(conversationId)).at(bottomMs) ?? stretch;
      if (await _showProven(conversationId, key, stretch)) return;
      if (stretch.done) return confirmEnd(conversationId, key);
    }
    await extendStretch(conversationId, key, stretch);
  }

  /// Shows the next page from the store, as far back as [stretch] vouches
  /// for it. False when the store has nothing more inside the stretch.
  Future<bool> _showProven(
    String conversationId,
    String key,
    FeedSpan stretch,
  ) async {
    final before = state.feeds[key]?.messages ?? const <ChatMessage>[];
    final shown = await showOlderFromDisk(
      conversationId,
      key,
      floorMs: stretch.done ? 0 : stretch.lowMs,
    );
    if (shown.added == 0) return false;
    if (!stretch.done) {
      final ahead = olderAhead[conversationId];
      if (shown.exhausted) {
        olderAhead[conversationId] = 0;
      } else if (ahead != null) {
        olderAhead[conversationId] = ahead > shown.added
            ? ahead - shown.added
            : 0;
      }
      syncAhead(conversationId, key);
    }
    // Drawn from disk already; now find out, behind the reader's back,
    // whether any of it changed while the phone was not listening.
    final anchor = olderAnchors(before, limit: 1).firstOrNull;
    if (anchor != null) refreshOlderShown(conversationId, anchor);
    return true;
  }

  /// A thread pages the way it always has: the server first while there is a
  /// cursor, the replies on disk when there is none or the request fails.
  Future<void> _loadOlderThread(
    String conversationId,
    String key,
    String threadRootId,
  ) async {
    final feed = state.feeds[key];
    if (feed == null || feed.loadingMore) return;
    setFeed(key, feed.copyWith(loadingMore: true));
    Future<bool> fromDisk() =>
        loadOlderFromDisk(conversationId, key, threadRootId: threadRootId);
    if (feed.nextCursor.isEmpty) {
      if (!await fromDisk()) _stopLoadingMore(key, hasMore: false);
      return;
    }
    try {
      final page = await repo.listMessages(
        conversationId,
        cursor: feed.nextCursor,
        limit: 100,
        thread: threadRootId,
      );
      final sorted = canonicalChatMessages(
        await decryptIfNeeded(page.messages),
      );
      await stageFeedPageThenAck(
        sorted,
        () => _acknowledge(conversationId, page.messages),
      );
      unawaited((this as _ChatPrivateMixin).takePrivateCustody(sorted));
      if (isDisposed) return;
      final latest = state.feeds[key] ?? feed;
      setFeed(
        key,
        latest.copyWith(
          messages: canonicalChatMessages([...latest.messages, ...sorted]),
          loadingMore: false,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      syncThreadSummary(threadRootId, sorted);
    } catch (_) {
      // Network gone mid-scroll: serve the older page from disk so the user
      // keeps reading instead of hitting a dead end.
      if (!await fromDisk()) _stopLoadingMore(key);
    }
  }
}
