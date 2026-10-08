part of 'chat_provider.dart';

/// What the newest page settled about the timeline on screen.
class _TopJoin {
  const _TopJoin(this.stretch, {required this.cutMs, required this.keepAll});

  /// The proven stretch the newest page belongs to — see [FeedSpan].
  final FeedSpan stretch;

  /// Nothing written before this is shown — see [fromCut].
  final int cutMs;

  /// The reader went back through local history nothing vouches for (a chat
  /// opened offline). It is left exactly as they have it.
  final bool keepAll;

  List<ChatMessage> shown(List<ChatMessage> messages) =>
      keepAll ? messages : fromCut(messages, cutMs);
}

/// Scrollback's memory for this session, and the one place the newest page
/// is checked against what is on screen.
mixin _ChatOlderTopMixin on Notifier<ChatState>, _ChatFeedMixin {
  FeedSpanStore get spanStore => ref.read(feedSpanStoreProvider);

  /// Feeds that have read past their first page this session.
  final pagedOlder = <String>{};

  /// Per conversation, rows stored and proven below the oldest one shown.
  /// Absent means not counted: plenty, or not known yet.
  final olderAhead = <String, int>{};

  /// Conversations whose first message the server confirmed is its first.
  final endConfirmed = <String>{};

  /// Conversations the server gave no usable answer for. They read the
  /// phone's own store for the rest of this session.
  final serverSilent = <String>{};

  /// Per feed, where a walk through unproven history stands.
  final walkCursor = <String, String>{};

  /// Records what the newest [page] proves, and says what may stay on screen.
  ///
  /// When the page reaches back to something already proven, the two are one
  /// stretch and nothing changes. When it does not — more arrived while the
  /// phone was away than one page holds — there is a hole between the page
  /// and the older rows on screen, and nothing marks it: the timeline would
  /// read as if those messages had never been sent. So the timeline restarts
  /// from the page, and scrolling back walks through the hole in order.
  Future<_TopJoin?> joinTopPage(
    String conversationId,
    String key,
    ChatMessagesPage page,
  ) async {
    if (page.messages.isEmpty) return null;
    var highMs = 0;
    for (final message in page.messages) {
      final ms = messageTimeMs(message);
      if (ms > highMs) highMs = ms;
    }
    int? bottomMs;
    for (final message in state.feeds[key]?.messages ?? const <ChatMessage>[]) {
      if (message.isPending) continue;
      bottomMs = messageTimeMs(message);
      break;
    }
    final before = await spanStore.read(conversationId);
    final wasProven = bottomMs != null && before.at(bottomMs) != null;
    final proved = spanOfPage(page, highMs: highMs);
    final spans = await spanStore.update(
      conversationId,
      (current) => current.add(proved),
    );
    final stretch = spans.at(highMs);
    if (stretch == null) return null;
    serverSilent.remove(conversationId);
    if (!page.hasMore) endConfirmed.add(conversationId);
    final connected =
        bottomMs == null || stretch.done || stretch.lowMs <= bottomMs;
    final keepAll = !connected && !wasProven && pagedOlder.contains(key);
    if (!connected && !keepAll) {
      pagedOlder.remove(key);
      olderAhead.remove(conversationId);
      walkCursor.remove(key);
    }
    // Connected, the screen keeps everything it has and the page adds only
    // what it can vouch for; restarted, the page's own range is all there is.
    final keepFrom = connected && bottomMs != null && bottomMs < proved.lowMs
        ? bottomMs
        : proved.lowMs;
    return _TopJoin(stretch, cutMs: keepFrom, keepAll: keepAll);
  }

  /// Every feed is being dropped (history reset, account switch).
  void resetOlderPaging() {
    pagedOlder.clear();
    olderAhead.clear();
    endConfirmed.clear();
    serverSilent.clear();
    walkCursor.clear();
  }

  /// One conversation's history left this phone.
  void forgetOlderPaging(String conversationId) {
    pagedOlder.removeWhere(
      (key) => key == conversationId || key.startsWith('$conversationId:'),
    );
    walkCursor.removeWhere(
      (key, _) => key == conversationId || key.startsWith('$conversationId:'),
    );
    olderAhead.remove(conversationId);
    endConfirmed.remove(conversationId);
    serverSilent.remove(conversationId);
  }
}
