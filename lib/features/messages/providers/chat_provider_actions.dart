part of 'chat_provider.dart';

mixin _ChatActionsMixin on Notifier<ChatState>, _ChatPatchMixin, _ChatFeedMixin {
  ChatRepository get repo;

  void incrementThreadCount(String conversationId, String rootId) {
    final key = feedKey(conversationId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages
            .map((m) => m.id == rootId
                ? m.copyWith(threadCount: m.threadCount + 1)
                : m)
            .toList(),
      ),
    );
  }

  void appendThreadReply(String rootId, ChatMessage msg) {
    final list = state.threadRepliesByRoot[rootId] ?? [];
    if (list.any((m) => m.id == msg.id)) return;
    state = state.copyWith(
      threadRepliesByRoot: {
        ...state.threadRepliesByRoot,
        rootId: [...list, msg],
      },
    );
  }

  void patchThreadReply(String rootId, ChatMessage msg) {
    final list = state.threadRepliesByRoot[rootId];
    if (list == null) return;
    state = state.copyWith(
      threadRepliesByRoot: {
        ...state.threadRepliesByRoot,
        rootId: list.map((m) => m.id == msg.id ? msg : m).toList(),
      },
    );
  }

  void markThreadReplyDeleted(String rootId, String messageId) {
    final list = state.threadRepliesByRoot[rootId];
    if (list == null) return;
    state = state.copyWith(
      threadRepliesByRoot: {
        ...state.threadRepliesByRoot,
        rootId: list
            .map((m) => m.id == messageId
                ? m.copyWith(
                    deletedAt: DateTime.now().toUtc().toIso8601String(),
                    body: '',
                  )
                : m)
            .toList(),
      },
    );
  }

  Future<ChatMessage?> sendMessage({
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
  }) async {
    final convId = state.activeConversationId;
    if (convId == null) return null;
    state = state.copyWith(sending: true);
    try {
      final msg = await repo.sendMessage(
        convId,
        body: body,
        parentId: parentId,
        attachments: attachments,
        mentionedUserIds: mentionedUserIds,
      );
      final threadRootId = state.threadRootId;
      if (parentId != null &&
          threadRootId != null &&
          parentId == threadRootId) {
        appendFeedMessage(convId, msg, threadRootId: threadRootId);
        appendThreadReply(threadRootId, msg);
      } else if (parentId == null) {
        appendFeedMessage(convId, msg);
      }
      applyIncomingMessage(convId, msg, bumpUnread: false);
      return msg;
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    state = state.copyWith(
      dms: patchList(state.dms, conversationId, unreadCount: 0),
      channels: patchList(state.channels, conversationId, unreadCount: 0),
    );
    try {
      await repo.markRead(conversationId);
    } catch (_) {}
  }

  Future<ChatConversation> createChannel({
    required String name,
    bool isPrivate = false,
  }) async {
    final channel = await repo.createChannel(
      name: name,
      slug: slugifyChannel(name),
      isPrivate: isPrivate,
    );
    upsertChannel(channel);
    return channel;
  }

  Future<ChatConversation> startDm(String userId) async {
    final dm = await repo.startDm(userId);
    upsertDm(dm);
    return dm;
  }
}
