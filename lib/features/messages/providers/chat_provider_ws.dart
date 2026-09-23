part of 'chat_provider.dart';

mixin _ChatWsMixin on Notifier<ChatState>, _ChatMutateMixin {
  @override
  ChatRepository get repo;
  WsClient get ws;
  bool get realtimeStarted;
  set realtimeStarted(bool v);
  StreamSubscription<Map<String, dynamic>>? get wsEventSub;
  set wsEventSub(StreamSubscription<Map<String, dynamic>>? v);
  StreamSubscription<void>? get wsReconnectSub;
  set wsReconnectSub(StreamSubscription<void>? v);
  StreamSubscription<void>? get wsDisconnectSub;
  set wsDisconnectSub(StreamSubscription<void>? v);
  Future<void> fetchSidebarSilent();

  Future<void> _onConversationDeleted(String conversationId) async {
    // Reconcile the server cutoff rather than wiping newer messages that may
    // have arrived while the deletion event was in flight.
    if (conversationId.isNotEmpty) await fetchSidebarSilent();
  }

  void handleWsEvent(Map<String, dynamic> ev) {
    final type = ev['type'] as String? ?? '';
    if (type == 'chat.conversation.updated') {
      unawaited(fetchSidebarSilent());
      return;
    }
    if (type == 'chat.peer_privacy') {
      ref
          .read(peerPrivacyOverridesProvider.notifier)
          .onEvent(ev, state.currentUserId);
      return;
    }
    // Sent to this account alone when the conversation is deleted — either
    // because the group is gone for everyone, or because the user deleted the
    // chat on another device. Either way this device is still holding the
    // whole history locally, so the wipe has to run here too.
    if (type == 'chat.conversation.deleted') {
      final deletedId = ev['conversation_id'] as String? ?? '';
      unawaited(_onConversationDeleted(deletedId));
      return;
    }
    if (type == 'chat.message.created') {
      unawaited(_onMessageCreated(ev));
      return;
    }
    // Apply updates/deletes/reactions to ANY loaded feed — not just the active
    // conversation. The feed map is keyed so only the right conv is affected.
    final convId = ev['conversation_id'] as String? ?? '';
    if (convId.isEmpty) return;

    if (type == 'chat.receipts.updated') {
      _applyReceiptUpdates(
        convId,
        ev['receipts'] as List<dynamic>? ?? const [],
      );
      return;
    }

    if (type == 'chat.message.updated') {
      final msgJson = ev['message'] as Map<String, dynamic>?;
      if (msgJson == null) return;
      unawaited(_onMessageUpdated(convId, msgJson));
      return;
    }

    if (type == 'chat.message.deleted') {
      final id = ev['id'] as String? ?? '';
      if (id.isEmpty) return;
      unawaited(
        ref
            .read(chatMessageStoreProvider)
            .deletions
            .rememberMessage(convId, id),
      );
      removeFeedMessage(convId, id);
      (this as _ChatCacheMixin).deleteCachedMessageAsync(id);
      // Remove from all known thread feeds.
      for (final rootId in state.threadRepliesByRoot.keys) {
        final threadKey = feedKey(convId, threadRootId: rootId);
        if (state.feeds.containsKey(threadKey)) {
          removeFeedMessage(convId, id, threadRootId: rootId);
        }
        markThreadReplyDeleted(rootId, id);
      }
    }

    if (type == 'chat.reaction.updated') {
      final id = ev['id'] as String? ?? '';
      final reactions = (ev['reactions'] as List<dynamic>? ?? [])
          .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
          .toList();
      updateFeedReactions(convId, id, reactions);
      // Update reactions in all loaded thread feeds for this conv.
      for (final rootId in state.threadRepliesByRoot.keys) {
        final threadKey = feedKey(convId, threadRootId: rootId);
        if (state.feeds.containsKey(threadKey)) {
          updateFeedReactions(convId, id, reactions, threadRootId: rootId);
        }
      }
      _persistFeedMessage(convId, id);
    }
  }

  void _applyReceiptUpdates(String convId, List<dynamic> rawUpdates) {
    final updates = <String, ChatDeliverySummary>{};
    for (final raw in rawUpdates) {
      if (raw is! Map) continue;
      final update = Map<String, dynamic>.from(raw);
      final id = update['message_id'] as String? ?? '';
      final delivery = update['delivery'];
      if (id.isNotEmpty && delivery is Map) {
        updates[id] = ChatDeliverySummary.fromJson(
          Map<String, dynamic>.from(delivery),
        );
      }
    }
    if (updates.isEmpty) return;
    final feeds = <String, ChatFeed>{};
    for (final entry in state.feeds.entries) {
      final belongs =
          entry.key == convId || entry.key.startsWith('$convId:thread:');
      feeds[entry.key] = belongs
          ? entry.value.copyWith(
              messages: entry.value.messages
                  .map(
                    (message) => updates[message.id] == null
                        ? message
                        : message.copyWith(delivery: updates[message.id]),
                  )
                  .toList(),
            )
          : entry.value;
    }
    final replies = <String, List<ChatMessage>>{};
    for (final entry in state.threadRepliesByRoot.entries) {
      replies[entry.key] = entry.value
          .map(
            (message) => updates[message.id] == null
                ? message
                : message.copyWith(delivery: updates[message.id]),
          )
          .toList();
    }
    state = state.copyWith(feeds: feeds, threadRepliesByRoot: replies);
  }

  /// Writes one already-patched message from the in-memory main feed back to
  /// SQLite — the reaction path, where the event itself carries no message.
  /// No-op if that feed was never loaded this session.
  void _persistFeedMessage(String convId, String messageId) {
    final feed = state.feeds[feedKey(convId)];
    if (feed == null) return;
    for (final m in feed.messages) {
      if (m.id == messageId) {
        (this as _ChatCacheMixin).persistMessageAsync(m);
        return;
      }
    }
  }

  Future<void> _onMessageCreated(Map<String, dynamic> ev) async {
    final convId = ev['conversation_id'] as String? ?? '';
    final msgJson = ev['message'] as Map<String, dynamic>?;
    if (msgJson == null) return;
    var msg = ChatMessage.fromJson(msgJson);
    if (msg.isEncrypted) {
      msg = await ref
          .read(messageVaultProvider)
          .decryptMessage(msg, state.currentUserId);
    }
    if (msg.userId == state.currentUserId) {
      (this as _ChatOutboxMixin).settleOutbox(msg).ignore();
    }
    final isActive = convId == state.activeConversationId;
    unawaited(
      repo.acknowledgeMessages('delivered', [msg.id]).catchError((_) {}),
    );
    if (isActive) {
      unawaited(repo.acknowledgeMessages('read', [msg.id]).catchError((_) {}));
      if (msg.userId != state.currentUserId) {
        // A receipt is per message; the sidebar badge counts against the
        // conversation's own read marker, and that only moved when the chat
        // opened. Without pushing it forward here, every message that arrives
        // while the reader is looking at the thread comes back as unread the
        // moment the sidebar is refetched.
        unawaited(repo.markRead(convId).catchError((_) {}));
        unawaited(
          ChatNotificationPresenter.dismiss(
            ref.read(localNotificationsProvider),
            convId,
          ),
        );
      }
    }
    final known =
        state.dms.any((d) => d.id == convId) ||
        state.channels.any((c) => c.id == convId);
    if (!known) unawaited(fetchSidebarSilent());

    final key = feedKey(convId, threadRootId: msg.parentId);
    final feedForConv = state.feeds[key];

    if (feedForConv != null) {
      // Already settled (HTTP, a previous WS, or a history page) — do not
      // append a second copy just because this event also carries clientRef.
      if (feedForConv.messages.any(
        (m) => !m.isPending && sameChatMessage(m, msg),
      )) {
        return;
      }

      // Match the sender-generated id when available. Falling back to the
      // first pending bubble is only for legacy server events.
      if (msg.userId == state.currentUserId) {
        // Only an unsettled bubble can be the pending copy of this event. The
        // server echoes client_message_id back, so without the isPending guard
        // an already-confirmed row would match itself here.
        ChatMessage? pendingMsg;
        for (final m in feedForConv.messages) {
          if (m.userId != state.currentUserId || !m.isPending) continue;
          final sameClientMessage =
              msg.clientRef != null && m.clientRef == msg.clientRef;
          final legacyPending = msg.clientRef == null;
          if (sameClientMessage || legacyPending) {
            pendingMsg = m;
            break;
          }
        }
        if (pendingMsg != null) {
          // WS arrived before HTTP returned: replace pending bubble now
          _replacePendingMessage(
            convId,
            pendingMsg.id,
            msg,
            parentId: msg.parentId,
          );
          unawaited(ref.read(attachmentIntakeProvider).onMessage(msg));
          (this as _ChatCacheMixin).persistMessageAsync(msg);
          return;
        }
      }
    }

    // Always update sidebar preview and unread badge.
    applyIncomingMessage(
      convId,
      msg,
      bumpUnread: !isActive && msg.userId != state.currentUserId,
    );

    // Always append to the in-memory feed if it exists.
    if (msg.parentId != null) {
      final parentId = msg.parentId!;
      appendFeedMessage(convId, msg, threadRootId: parentId);
      if (appendThreadReply(parentId, msg)) {
        incrementThreadCount(convId, parentId);
      }
    } else {
      appendFeedMessage(convId, msg);
    }
    unawaited(ref.read(attachmentIntakeProvider).onMessage(msg));
    (this as _ChatCacheMixin).persistMessageAsync(msg);
  }

  Future<void> _onMessageUpdated(
    String convId,
    Map<String, dynamic> msgJson,
  ) async {
    var msg = ChatMessage.fromJson(msgJson);
    if (msg.isEncrypted) {
      msg = await ref
          .read(messageVaultProvider)
          .decryptMessage(msg, state.currentUserId);
    }
    // A timed photo that just expired arrives with its URL blanked; the
    // bytes this phone holds are found under the URL the old copy carried.
    final previous = state.feeds[feedKey(convId)]?.messages
        .where((m) => m.id == msg.id)
        .firstOrNull;
    unawaited(wipeExpiredMedia(ref, previous, msg));
    updateFeedMessage(convId, msg);
    final threadRootId = msg.parentId ?? state.threadRootId;
    if (threadRootId != null) {
      updateFeedMessage(convId, msg, threadRootId: threadRootId);
    }
    if (msg.parentId != null) {
      patchThreadReply(msg.parentId!, msg);
    }
    unawaited(ref.read(attachmentIntakeProvider).onMessage(msg));
    (this as _ChatCacheMixin).persistMessageAsync(msg);
  }

  void initRealtime() {
    if (realtimeStarted) return;
    realtimeStarted = true;
    wsEventSub = ws.events.listen((ev) {
      final type = ev['type'] as String? ?? '';
      if (type.startsWith('chat.')) handleWsEvent(ev);
    });
    wsReconnectSub = ws.reconnects.listen((_) {
      state = state.copyWith(wsConnected: true);
      // A reconnect means there was a gap, whatever opened it. The same catch-up
      // runs when the app returns to the foreground — see `_ChatResyncMixin`.
      (this as _ChatResyncMixin).resyncNow();
    });
    wsDisconnectSub = ws.disconnects.listen((_) {
      state = state.copyWith(wsConnected: false);
    });
    unawaited(ws.connect());
  }

  void disposeRealtime() {
    realtimeStarted = false;
    unawaited(wsEventSub?.cancel());
    unawaited(wsReconnectSub?.cancel());
    unawaited(wsDisconnectSub?.cancel());
    wsEventSub = null;
    wsReconnectSub = null;
    wsDisconnectSub = null;
  }
}
