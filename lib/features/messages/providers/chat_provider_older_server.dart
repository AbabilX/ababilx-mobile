part of 'chat_provider.dart';

/// One page of older history from the server, already stored.
typedef _OlderPull = ({ChatMessagesPage page, List<ChatMessage> messages});

/// The server's answer to "what is older than this?".
typedef _OlderAnswer = ({_OlderPull? pull, int fromMs, bool canTell});

/// Older history the phone does not hold yet, fetched and stored — the only
/// place scrollback touches the network for messages it has never seen.
mixin _ChatOlderServerMixin
    on
        Notifier<ChatState>,
        _ChatFeedMixin,
        _ChatCacheMixin,
        _ChatOlderTopMixin {
  final _aheadRuns = <String, Future<void>>{};

  /// Fetches the page after [cursor], decrypts it and stores it. Nothing is
  /// drawn here; the caller decides what reaches the screen.
  Future<_OlderPull> pullOlder(String conversationId, String cursor) async {
    final clock = ChatOlderTrace.start();
    final page = await repo
        .listMessages(conversationId, cursor: cursor, limit: diskPageSize)
        .timeout(olderPageTimeout);
    final messages = await (this as _ChatOlderDiskMixin).keepingStoredContent(
      canonicalChatMessages(await decryptIfNeeded(page.messages)),
    );
    // These rows are new to this phone, so this is their delivery — once
    // they are on disk, not before.
    await stageFeedPageThenAck(
      messages,
      () => _acknowledge(conversationId, page.messages),
    );
    unawaited((this as _ChatPrivateMixin).takePrivateCustody(messages));
    ChatOlderTrace.end(clock, conversationId, 'server', messages.length);
    return (page: page, messages: messages);
  }

  /// [pullOlder], with an empty answer checked before it is believed.
  ///
  /// The cursor is a message id, and the server answers an id it no longer
  /// holds — deleted, or a private-chat message it let go — with the same
  /// empty page as "nothing older". Reading that as the end would close the
  /// history for good. So an empty page is asked again from messages on
  /// screen the server must still have. `canTell` is false when there is no
  /// such message to ask from.
  Future<_OlderAnswer> pullOlderChecked(
    String conversationId, {
    required String cursor,
    required int fromMs,
    required List<ChatMessage> window,
  }) async {
    final first = await pullOlder(conversationId, cursor);
    if (first.page.messages.isNotEmpty) {
      return (pull: first, fromMs: fromMs, canTell: true);
    }
    final anchors = olderAnchors(window).where((m) => m.id != cursor).toList();
    if (anchors.isEmpty) return (pull: null, fromMs: fromMs, canTell: false);
    for (final anchor in anchors) {
      final again = await pullOlder(conversationId, anchor.id);
      if (again.page.messages.isNotEmpty) {
        return (pull: again, fromMs: messageTimeMs(anchor), canTell: true);
      }
    }
    return (pull: first, fromMs: fromMs, canTell: true);
  }

  /// Adds what [pull] proves to the conversation's stretches and returns the
  /// one it now belongs to. Also keeps [olderAhead] honest: reaching an
  /// older stretch means there is a long way proven below, so the count
  /// stops mattering.
  Future<FeedSpan?> recordOlderPage(
    String conversationId,
    _OlderPull pull, {
    required int fromMs,
  }) async {
    final added = spanOfPage(pull.page, highMs: fromMs);
    final spans = await spanStore.update(
      conversationId,
      (current) => current.add(added),
    );
    final stretch = spans.at(fromMs);
    if (added.done) endConfirmed.add(conversationId);
    if (stretch == null || stretch.lowMs < added.lowMs) {
      olderAhead.remove(conversationId);
    }
    return stretch;
  }

  /// Keeps a few pages fetched, stored and proven beyond what is on screen
  /// while the chat is open, so the next pages of scrollback come off the
  /// disk. One run per conversation at a time; it stops as soon as enough is
  /// ahead, the server has no more, or the chat is closed.
  void syncAhead(String conversationId, String key) {
    if (_aheadRuns.containsKey(conversationId)) return;
    _aheadRuns[conversationId] = _runAhead(conversationId, key).whenComplete(
      () {
        _aheadRuns.remove(conversationId);
      },
    );
  }

  Future<void> _runAhead(String conversationId, String key) async {
    try {
      for (var round = 0; round < 3; round++) {
        if (isDisposed || state.activeConversationId != conversationId) return;
        final ahead = olderAhead[conversationId];
        if (ahead == null || ahead >= olderAheadRows) return;
        final window = state.feeds[key]?.messages ?? const <ChatMessage>[];
        if (window.isEmpty) return;
        final spans = await spanStore.read(conversationId);
        final stretch = spans.at(messageTimeMs(window.first));
        if (stretch == null || stretch.done || stretch.cursor.isEmpty) return;
        final pull = await pullOlder(conversationId, stretch.cursor);
        // An empty page here is for the reader's own load to check and act on.
        if (isDisposed || pull.page.messages.isEmpty) return;
        final joined = await recordOlderPage(
          conversationId,
          pull,
          fromMs: stretch.lowMs,
        );
        if (joined == null || !olderAhead.containsKey(conversationId)) return;
        olderAhead[conversationId] =
            (olderAhead[conversationId] ?? 0) + pull.messages.length;
      }
    } catch (_) {
      // Offline or slow: the reader's own load falls back to the store.
    }
  }
}
