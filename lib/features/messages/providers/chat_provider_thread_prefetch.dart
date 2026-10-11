part of 'chat_provider.dart';

/// Fills [ChatState.threadRepliesByRoot] without opening the thread sheet.
///
/// The gray last-reply line under a bubble reads that map, not the main feed.
/// Web already prefetches the thread page for this; without it the phone only
/// had a count until the user tapped in.
mixin _ChatThreadPrefetchMixin
    on Notifier<ChatState>, _ChatFeedMixin, _ChatCacheMixin {
  @override
  ChatMessageStore get messageStore;

  final _threadPrefetchInFlight = <String>{};

  void prefetchThreadSummaries(String conversationId) {
    if (conversationId.isEmpty || isDisposed) return;
    final feed = state.feeds[feedKey(conversationId)];
    if (feed == null) return;
    for (final root in threadRootsNeedingPreview(
      feed.messages,
      state.threadRepliesByRoot,
    )) {
      unawaited(_prefetchOne(conversationId, root.id, root.threadCount));
    }
  }

  Future<void> _prefetchOne(
    String conversationId,
    String rootId,
    int threadCount,
  ) async {
    final key = '$conversationId:$rootId';
    if (!_threadPrefetchInFlight.add(key)) return;
    try {
      await _hydrateThreadPreviewFromDisk(conversationId, rootId);
      if (isDisposed) return;
      if (!_stillNeedsPreview(rootId, threadCount)) return;

      final page = await repo.listMessages(
        conversationId,
        limit: 100,
        thread: rootId,
      );
      final messages = await decryptIfNeeded(page.messages);
      final replies = canonicalChatMessages(
        messages.where((m) => m.id != rootId),
      );
      unawaited(
        repo
            .acknowledgeMessages(
              'delivered',
              page.messages.map((message) => message.id).toList(),
            )
            .catchError((_) {}),
      );
      await persistFeed(messages);
      if (isDisposed) return;
      _mergeThreadReplies(rootId, replies);
    } catch (_) {
      // Preview stays blank; opening the thread still loads the sheet.
    } finally {
      _threadPrefetchInFlight.remove(key);
    }
  }

  Future<void> _hydrateThreadPreviewFromDisk(
    String conversationId,
    String rootId,
  ) async {
    if (state.threadRepliesByRoot[rootId]?.isNotEmpty ?? false) return;
    final cached = await messageStore.page(
      conversationId,
      limit: 100,
      threadRootId: rootId,
    );
    if (cached.isEmpty || isDisposed) return;
    final decrypted = sendTracker.settle(await decryptIfNeeded(cached));
    if (isDisposed) return;
    _mergeThreadReplies(rootId, decrypted.where((m) => m.id != rootId));
  }

  bool _stillNeedsPreview(String rootId, int threadCount) {
    return (state.threadRepliesByRoot[rootId]?.length ?? 0) < threadCount;
  }

  void _mergeThreadReplies(String rootId, Iterable<ChatMessage> incoming) {
    final merged = canonicalChatMessages([
      ...?state.threadRepliesByRoot[rootId],
      ...incoming,
    ]);
    if (merged.isEmpty) return;
    final current = state.threadRepliesByRoot[rootId];
    if (current != null &&
        current.length == merged.length &&
        current.last.id == merged.last.id) {
      return;
    }
    state = state.copyWith(
      threadRepliesByRoot: {...state.threadRepliesByRoot, rootId: merged},
    );
  }
}
