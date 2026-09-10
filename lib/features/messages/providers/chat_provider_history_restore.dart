part of 'chat_provider.dart';

/// Recovery scans every available page, including thread replies. A cached
/// first page is not evidence that the conversation's history is complete.
mixin _ChatHistoryRestoreMixin
    on Notifier<ChatState>, _ChatFeedMixin, _ChatCacheMixin {
  @override
  ChatRepository get repo;
  Future<void>? _restoreInFlight;
  bool _restoreCancelled = false;

  Future<void> cancelHistoryRestore() async {
    _restoreCancelled = true;
    try {
      await _restoreInFlight;
    } catch (_) {}
  }

  Future<void> completeHistoryReset(String userId) async {
    await HistoryRestoreFlag.complete(userId);
    state = state.copyWith(
      feeds: const {},
      threadRepliesByRoot: const {},
      searchResults: const [],
      dms: state.dms.map((c) => c.withoutMessagePreview()).toList(),
      channels: state.channels.map((c) => c.withoutMessagePreview()).toList(),
    );
  }

  Future<void> markHistoryRestorePending() async {
    _restoreCancelled = false;
    await HistoryRestoreFlag.mark(
      await (this as ChatNotifier).ensureCurrentUserId(),
    );
  }

  Future<void> startHistoryRestoreIfNeeded() => _restoreInFlight ??=
      _runHistoryRestore().whenComplete(() => _restoreInFlight = null);

  Future<void> _runHistoryRestore() async {
    if (isDisposed ||
        _restoreCancelled ||
        !ref.read(messageVaultProvider).isUnlocked) {
      return;
    }
    final userId = state.currentUserId.trim();
    if (userId.isEmpty || !await HistoryRestoreFlag.isPending(userId)) return;
    await ref.read(archiveProvider.notifier).restoreAfterRecovery();
    if (isDisposed || _restoreCancelled) return;
    final public = ref.read(messageVaultProvider).publicIdentity;
    bool stopped() =>
        isDisposed ||
        _restoreCancelled ||
        state.currentUserId != userId ||
        ref.read(messageVaultProvider).publicIdentity?['x'] != public?['x'];
    final ids = {
      ...state.dms.map((c) => c.id),
      ...state.channels.map((c) => c.id),
    }.toList();
    // An empty sidebar may be an offline fetch, not an empty account. Retry on
    // the next successful bootstrap rather than consuming the restore intent.
    if (ids.isEmpty || stopped()) return;
    final status = ref.read(historyRestoreProvider.notifier);
    status.begin(ids.length);
    var failed = false;
    try {
      await syncChatDeletions(ref, userId);
      await runHistoryRestore(
        ids: ids,
        shouldStop: stopped,
        pull: (id) async {
          try {
            await _restoreConversation(id, stopped);
          } catch (_) {
            failed = true;
          }
        },
        onProgress: (done, total) {
          if (!stopped()) status.progress(done, total);
        },
      );
      if (!stopped() && !failed) await HistoryRestoreFlag.complete(userId);
    } catch (_) {
      failed = true;
    } finally {
      if (!isDisposed) status.finish(failed: failed);
    }
  }

  Future<void> _restoreConversation(String id, bool Function() stopped) async {
    final threads = <String>{};
    Future<void> pages({String? thread}) async {
      String? cursor;
      final seen = <String>{};
      while (!stopped()) {
        final page = await repo
            .listMessages(id, cursor: cursor, thread: thread, limit: 100)
            .timeout(firstLoadNetworkTimeout);
        if (stopped()) return;
        final messages = await decryptIfNeeded(
          page.messages.where((m) => !m.contentPurged).toList(),
        );
        if (stopped()) return;
        await messageStore.saveRecovered(
          canonicalChatMessages(messages),
          fromBackup: false,
        );
        if (stopped()) return;
        unawaited(
          repo
              .acknowledgeMessages(
                'delivered',
                page.messages.map((m) => m.id).toList(),
              )
              .catchError((_) {}),
        );
        unawaited(ref.read(attachmentIntakeProvider).onMessages(messages));
        if (thread == null) {
          threads.addAll(
            page.messages.where((m) => m.threadCount > 0).map((m) => m.id),
          );
        }
        if (!page.hasMore) break;
        if (page.nextCursor.isEmpty || !seen.add(page.nextCursor)) {
          throw StateError('Recovery pagination did not advance');
        }
        cursor = page.nextCursor;
      }
    }

    await pages();
    for (final root in threads) {
      if (stopped()) return;
      await pages(thread: root);
    }
  }
}
