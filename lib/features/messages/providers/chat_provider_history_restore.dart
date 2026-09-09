part of 'chat_provider.dart';

/// After a recovery-code unlock, pull the newest page of every sidebar chat
/// into the local store so the user does not have to open each one.
///
/// Runs **once** per install after recovery (`HistoryRestoreFlag`). Deliberately
/// not [loadFeed]: that path marks the conversation read when it is active and
/// owns the in-memory feed. Restore writes disk, acks delivered only, and
/// follows auto-download for media. If the user opens a chat while this runs,
/// that conversation is skipped — [loadFeed] already has it.
mixin _ChatHistoryRestoreMixin
    on Notifier<ChatState>, _ChatFeedMixin, _ChatCacheMixin {
  @override
  ChatRepository get repo;

  Future<void>? _restoreInFlight;
  bool _restoreCancelled = false;

  Future<void> markHistoryRestorePending() async {
    _restoreCancelled = false;
    final userId = await (this as ChatNotifier).ensureCurrentUserId();
    await HistoryRestoreFlag.mark(userId);
  }

  Future<void> startHistoryRestoreIfNeeded() {
    return _restoreInFlight ??= _runHistoryRestore().whenComplete(() {
      _restoreInFlight = null;
    });
  }

  Future<void> _runHistoryRestore() async {
    if (isDisposed || _restoreCancelled) return;
    if (!ref.read(messageVaultProvider).isUnlocked) return;
    final userId = state.currentUserId.trim();
    if (userId.isEmpty) return;
    if (!await HistoryRestoreFlag.isPending(userId)) return;
    if (ref.read(historyRestoreProvider).running) return;

    final conversations = [...state.dms, ...state.channels];
    if (conversations.isEmpty) {
      if (!_restoreCancelled) await HistoryRestoreFlag.complete(userId);
      return;
    }

    final alreadyOnDisk = <String>{};
    for (final conversation in conversations) {
      final cached = await messageStore.page(conversation.id, limit: 1);
      if (cached.isNotEmpty) alreadyOnDisk.add(conversation.id);
    }
    if (isDisposed || _restoreCancelled) return;

    final alreadyLive = <String>{
      for (final conversation in conversations)
        if (_restoreShouldSkipLive(conversation.id)) conversation.id,
    };

    final ids = conversationIdsNeedingRestore(
      conversations: conversations,
      alreadyOnDisk: alreadyOnDisk,
      alreadyLive: alreadyLive,
    );
    if (ids.isEmpty) {
      if (!_restoreCancelled) await HistoryRestoreFlag.complete(userId);
      return;
    }

    ref.read(historyRestoreProvider.notifier).begin(ids.length);
    try {
      await runHistoryRestore(
        ids: ids,
        pull: _restoreNewestPage,
        onProgress: (done, total) {
          if (!isDisposed) {
            ref.read(historyRestoreProvider.notifier).progress(done, total);
          }
        },
        shouldStop: () => isDisposed || _restoreCancelled,
      );
    } finally {
      if (!_restoreCancelled) {
        await HistoryRestoreFlag.complete(userId);
      }
      if (!isDisposed) {
        ref.read(historyRestoreProvider.notifier).finish();
      }
    }
  }

  /// [loadFeed] owns any conversation the user has opened. Touching that feed
  /// from restore races the timeline (read receipts, cursors, loading flags).
  bool _restoreShouldSkipLive(String conversationId) {
    if (state.activeConversationId == conversationId) return true;
    final feed = state.feeds[feedKey(conversationId)];
    return feed != null && (feed.messages.isNotEmpty || feed.loading);
  }

  Future<void> _restoreNewestPage(String conversationId) async {
    if (isDisposed || _restoreCancelled || conversationId.isEmpty) return;
    if (_restoreShouldSkipLive(conversationId)) return;
    final cached = await messageStore.page(conversationId, limit: 1);
    if (cached.isNotEmpty) return;

    final page = await repo
        .listMessages(conversationId, limit: 50)
        .timeout(firstLoadNetworkTimeout);
    final sorted = canonicalChatMessages(await decryptIfNeeded(page.messages));
    unawaited(
      repo
          .acknowledgeMessages(
            'delivered',
            page.messages.map((message) => message.id).toList(),
          )
          .catchError((_) {}),
    );
    await persistFeed(sorted);
    unawaited(ref.read(attachmentIntakeProvider).onMessages(sorted));
  }
}
