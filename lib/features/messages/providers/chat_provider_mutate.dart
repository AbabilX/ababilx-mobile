part of 'chat_provider.dart';

mixin _ChatMutateMixin on Notifier<ChatState>, _ChatActionsMixin {
  ChatRepository get repo;

  Future<void> toggleReaction(String messageId, String emoji) async {
    final reactions = await repo.toggleReaction(messageId, emoji);
    final convId = state.activeConversationId;
    if (convId == null) return;
    updateFeedReactions(convId, messageId, reactions);
    updateFeedReactions(
      convId,
      messageId,
      reactions,
      threadRootId: state.threadRootId,
    );
  }

  Future<void> editMessage(String messageId, String body) async {
    final msg = await repo.patchMessage(messageId, body);
    final convId = state.activeConversationId;
    if (convId == null) return;
    updateFeedMessage(convId, msg);
    updateFeedMessage(convId, msg, threadRootId: state.threadRootId);
    if (msg.parentId != null) patchThreadReply(msg.parentId!, msg);
  }

  Future<void> deleteMessage(String messageId) async {
    await repo.deleteMessage(messageId);
    final convId = state.activeConversationId;
    if (convId == null) return;
    removeFeedMessage(convId, messageId);
    removeFeedMessage(convId, messageId, threadRootId: state.threadRootId);
    for (final rootId in state.threadRepliesByRoot.keys) {
      markThreadReplyDeleted(rootId, messageId);
    }
  }

  Future<int> forwardMessage({
    required String messageId,
    List<String>? conversationIds,
    List<String>? userIds,
    String? caption,
  }) =>
      repo.forwardMessage(
        messageId: messageId,
        conversationIds: conversationIds,
        userIds: userIds,
        caption: caption,
      );

  Future<void> searchMessages(String q) async {
    state = state.copyWith(searchQuery: q, searchLoading: true);
    try {
      final results = await repo.searchMessages(q);
      state = state.copyWith(searchResults: results, searchLoading: false);
    } catch (_) {
      state = state.copyWith(searchResults: [], searchLoading: false);
    }
  }

  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) =>
      repo.presignAttachment(
        conversationId,
        contentType: contentType,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );

  Future<void> uploadAttachmentBytes(
    ChatPresignResult presign,
    List<int> bytes,
    String contentType,
  ) async {
    final dio = Dio();
    await dio.put(
      presign.uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
    );
  }

  Future<void> discardUpload(String conversationId, String fileUrl) =>
      repo.discardUpload(conversationId, fileUrl);

  Future<ChatConversation> renameChannel(String id, String name) async {
    final updated = await repo.patchChannel(id, name: name);
    upsertChannel(updated);
    return updated;
  }

  Future<void> muteConversation(String id, bool muted) async {
    await repo.muteConversation(id, muted);
    state = state.copyWith(
      dms: patchList(state.dms, id, muted: muted),
      channels: patchList(state.channels, id, muted: muted),
    );
  }

  Future<List<ChatMember>> listChannelMembers(String channelId) =>
      repo.listChannelMembers(channelId);

  Future<void> addChannelMember(String channelId, String userId) =>
      repo.addChannelMember(channelId, userId);

  Future<void> leaveChannel(String channelId) async {
    await repo.leaveChannel(channelId);
    await (this as ChatNotifier).fetchSidebar(silent: true);
  }

  Future<void> deleteChannel(String channelId) async {
    await repo.deleteChannel(channelId);
    await (this as ChatNotifier).fetchSidebar(silent: true);
  }
}
