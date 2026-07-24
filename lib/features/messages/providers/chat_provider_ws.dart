part of 'chat_provider.dart';

mixin _ChatWsMixin on Notifier<ChatState>, _ChatMutateMixin {
  WsClient get ws;
  bool get realtimeStarted;
  set realtimeStarted(bool v);
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
    final convId = ev['conversation_id'] as String? ?? '';
    if (convId != state.activeConversationId) return;
    if (type == 'chat.message.updated') {
      final msgJson = ev['message'] as Map<String, dynamic>?;
      if (msgJson == null) return;
      final msg = ChatMessage.fromJson(msgJson);
      updateFeedMessage(convId, msg);
      updateFeedMessage(convId, msg, threadRootId: state.threadRootId);
      if (msg.parentId != null) patchThreadReply(msg.parentId!, msg);
    }
    if (type == 'chat.message.deleted') {
      final id = ev['id'] as String? ?? '';
      removeFeedMessage(convId, id);
      removeFeedMessage(convId, id, threadRootId: state.threadRootId);
      for (final rootId in state.threadRepliesByRoot.keys) {
        markThreadReplyDeleted(rootId, id);
      }
    }
    if (type == 'chat.reaction.updated') {
      final id = ev['id'] as String? ?? '';
      final reactions = (ev['reactions'] as List<dynamic>? ?? [])
          .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
          .toList();
      updateFeedReactions(convId, id, reactions);
      updateFeedReactions(
        convId,
        id,
        reactions,
        threadRootId: state.threadRootId,
      );
    }
  }

  void _onMessageCreated(Map<String, dynamic> ev) {
    final convId = ev['conversation_id'] as String? ?? '';
    final msgJson = ev['message'] as Map<String, dynamic>?;
    if (msgJson == null) return;
    final msg = ChatMessage.fromJson(msgJson);
    final isActive = convId == state.activeConversationId;
    final known = state.dms.any((d) => d.id == convId) ||
        state.channels.any((c) => c.id == convId);
    if (!known) unawaited(fetchSidebarSilent());
    if (!isActive) {
      applyIncomingMessage(
        convId,
        msg,
        bumpUnread: msg.userId != state.currentUserId,
      );
      return;
    }
    applyIncomingMessage(convId, msg, bumpUnread: false);
    if (msg.parentId != null) {
      final threadRootId = state.threadRootId;
      if (threadRootId != null && msg.parentId == threadRootId) {
        appendFeedMessage(convId, msg, threadRootId: threadRootId);
        appendThreadReply(threadRootId, msg);
      } else {
        incrementThreadCount(convId, msg.parentId!);
        appendThreadReply(msg.parentId!, msg);
      }
    } else {
      appendFeedMessage(convId, msg);
    }
  }

  void initRealtime() {
    if (realtimeStarted) return;
    realtimeStarted = true;
    ws.onEvent = (ev) {
      final type = ev['type'] as String? ?? '';
      if (type.startsWith('chat.')) handleWsEvent(ev);
    };
    ws.onReconnect = () {
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
    };
    unawaited(ws.connect());
  }

  void disposeRealtime() {
    realtimeStarted = false;
    ws.disconnect();
  }
}
