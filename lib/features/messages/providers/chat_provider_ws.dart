part of 'chat_provider.dart';

mixin _ChatWsMixin on Notifier<ChatState>, _ChatMutateMixin {
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

  void handleWsEvent(Map<String, dynamic> ev) {
    final type = ev['type'] as String? ?? '';
    if (type == 'chat.conversation.updated') {
      unawaited(fetchSidebarSilent());
      return;
    }
    if (type == 'chat.message.created') {
      _onMessageCreated(ev);
      return;
    }
    // Apply updates/deletes/reactions to ANY loaded feed — not just the active
    // conversation. The feed map is keyed so only the right conv is affected.
    final convId = ev['conversation_id'] as String? ?? '';
    if (convId.isEmpty) return;

    if (type == 'chat.message.updated') {
      final msgJson = ev['message'] as Map<String, dynamic>?;
      if (msgJson == null) return;
      final msg = ChatMessage.fromJson(msgJson);
      // Update the main conversation feed.
      updateFeedMessage(convId, msg);
      // Update any relevant thread feed (parentId from msg, or any open thread).
      final threadRootId = msg.parentId ?? state.threadRootId;
      if (threadRootId != null) {
        updateFeedMessage(convId, msg, threadRootId: threadRootId);
      }
      // Patch thread replies preview map (sidebar thread summary).
      if (msg.parentId != null) patchThreadReply(msg.parentId!, msg);
    }

    if (type == 'chat.message.deleted') {
      final id = ev['id'] as String? ?? '';
      if (id.isEmpty) return;
      removeFeedMessage(convId, id);
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
    }
  }

  void _onMessageCreated(Map<String, dynamic> ev) {
    final convId = ev['conversation_id'] as String? ?? '';
    final msgJson = ev['message'] as Map<String, dynamic>?;
    if (msgJson == null) return;
    final msg = ChatMessage.fromJson(msgJson);
    final isActive = convId == state.activeConversationId;
    final known =
        state.dms.any((d) => d.id == convId) ||
        state.channels.any((c) => c.id == convId);
    if (!known) unawaited(fetchSidebarSilent());

    // Always update sidebar preview and unread badge.
    applyIncomingMessage(
      convId,
      msg,
      bumpUnread: !isActive && msg.userId != state.currentUserId,
    );

    // Always append to the in-memory feed if it exists, so switching to this
    // conversation immediately shows the latest message without a reload.
    if (msg.parentId != null) {
      final parentId = msg.parentId!;
      appendFeedMessage(convId, msg, threadRootId: parentId);
      if (appendThreadReply(parentId, msg)) {
        incrementThreadCount(convId, parentId);
      }
    } else {
      appendFeedMessage(convId, msg);
    }
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
      unawaited(fetchSidebarSilent());
      final active = state.activeConversationId;
      if (active != null) {
        unawaited(loadFeed(active, force: true));
        final thread = state.threadRootId;
        if (thread != null) {
          unawaited(loadFeed(active, threadRootId: thread, force: true));
        }
      }
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
