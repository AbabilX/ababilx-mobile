part of 'chat_provider.dart';

/// Brings older messages read from the phone's store up to date, after they
/// are already on screen.
///
/// The store is where scrollback comes from, and it can be behind: a
/// reaction, an edit or a read receipt that happened while the socket was
/// away never reached it, and receipts are not written to it at all. Nothing
/// waits for this — the page is drawn from disk at once and corrected in
/// place a moment later, and only the rows that really changed are opened
/// and written back.
mixin _ChatOlderRefreshMixin
    on Notifier<ChatState>, _ChatFeedMixin, _ChatCacheMixin {
  /// "conversation|message id" pairs already checked since the socket last
  /// came back. Within one connection every change arrives live, so a page
  /// needs checking once.
  final _refreshed = <String>{};
  final _refreshWaiting = <String, List<String>>{};
  final _refreshRuns = <String, Future<void>>{};

  /// More pages than this waiting means the reader is flinging through
  /// history; the oldest request gives way and is asked again when shown.
  static const _refreshBacklog = 6;

  /// A reconnect or a return to the foreground: anything may have changed
  /// while the phone was not listening.
  void forgetRefreshedOlder() => _refreshed.clear();

  /// Every feed is being dropped (history reset, account switch).
  void resetOlderRefresh() {
    _refreshed.clear();
    for (final waiting in _refreshWaiting.values) {
      waiting.clear();
    }
  }

  /// Asks for the page hanging below [anchor] to be checked against the
  /// server. [always] is for history nothing vouches for, where the check is
  /// also what finds a message the phone never received.
  void refreshOlderShown(
    String conversationId,
    ChatMessage anchor, {
    bool always = false,
  }) {
    if (!always && !worthRefreshing(anchor, DateTime.now())) return;
    final anchorId = anchor.id;
    final mark = '$conversationId|$anchorId';
    if (anchorId.isEmpty || !_refreshed.add(mark)) return;
    final waiting = _refreshWaiting.putIfAbsent(conversationId, () => []);
    waiting.add(anchorId);
    if (waiting.length > _refreshBacklog) {
      _refreshed.remove('$conversationId|${waiting.removeAt(0)}');
    }
    if (_refreshRuns.containsKey(conversationId)) return;
    _refreshRuns[conversationId] = _drainRefresh(conversationId).whenComplete(
      () {
        _refreshRuns.remove(conversationId);
      },
    );
  }

  Future<void> _drainRefresh(String conversationId) async {
    final waiting = _refreshWaiting[conversationId] ?? [];
    while (waiting.isNotEmpty) {
      final anchorId = waiting.removeAt(0);
      final open = !isDisposed && state.activeConversationId == conversationId;
      try {
        if (!open) throw StateError('conversation closed');
        await _refreshBelow(conversationId, anchorId);
      } catch (_) {
        // Closed or offline: none of these were checked, so each is asked
        // again the next time its page is shown.
        for (final id in [anchorId, ...waiting]) {
          _refreshed.remove('$conversationId|$id');
        }
        waiting.clear();
      }
    }
  }

  Future<void> _refreshBelow(String conversationId, String anchorId) async {
    final clock = ChatOlderTrace.start();
    final page = await repo
        .listMessages(conversationId, cursor: anchorId, limit: diskPageSize)
        .timeout(olderPageTimeout);
    if (isDisposed || page.messages.isEmpty) return;
    final key = feedKey(conversationId);
    final shown = {
      for (final m in state.feeds[key]?.messages ?? const <ChatMessage>[])
        m.id: m,
    };
    final newer = <ChatMessage>[];
    final patched = <ChatMessage>[];
    for (final server in page.messages) {
      // A copy the server has blanked says nothing the phone should take.
      if (server.contentPurged) continue;
      final local = shown[server.id];
      switch (compareServerCopy(local, server)) {
        case ServerCopy.same:
          break;
        case ServerCopy.receipts:
          patched.add(local!.copyWith(delivery: server.delivery));
        case ServerCopy.newer:
          // The stored row is keyed by the send's own id when it has one.
          newer.add(
            server.clientRef == null && local?.clientRef != null
                ? server.copyWith(clientRef: local!.clientRef)
                : server,
          );
      }
    }
    ChatOlderTrace.end(
      clock,
      conversationId,
      'refresh',
      newer.length + patched.length,
    );
    if (newer.isEmpty && patched.isEmpty) return;
    final fresh = [...patched, ...await decryptIfNeeded(newer)];
    await persistFeed(fresh);
    if (isDisposed) return;
    final latest = state.feeds[key];
    if (latest == null || latest.messages.isEmpty) return;
    // A row already on screen is replaced where it stands. One the phone
    // never had goes in only inside what is shown; anything older waits on
    // disk for the reader to reach it.
    final onScreen = latest.messages.map((m) => m.id).toSet();
    final bottomMs = messageTimeMs(latest.messages.first);
    final wanted = [
      for (final message in fresh)
        if (onScreen.contains(message.id) || messageTimeMs(message) >= bottomMs)
          message,
    ];
    if (wanted.isEmpty) return;
    setFeed(
      key,
      latest.copyWith(
        messages: canonicalChatMessages([...latest.messages, ...wanted]),
      ),
    );
    unawaited(ref.read(attachmentIntakeProvider).onMessages(wanted));
  }
}
