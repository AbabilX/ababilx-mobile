part of 'chat_provider.dart';

mixin _ChatMutateMixin
    on Notifier<ChatState>, _ChatActionsMixin, _ChatFeedEditMixin {
  @override
  ChatRepository get repo;

  Future<void> toggleReaction(String messageId, String emoji) async {
    final reactions = await repo.toggleReaction(messageId, emoji);
    final convId = state.activeConversationId;
    if (convId == null) return;
    updateFeedReactions(convId, messageId, reactions);
    final thread = state.threadRootId;
    if (thread != null) {
      updateFeedReactions(convId, messageId, reactions, threadRootId: thread);
    }
  }

  Future<void> editMessage(String messageId, String body) async {
    final convId = state.activeConversationId;
    if (convId == null) return;
    final conversation = state.conversationById(convId);
    EncryptedDmPayload? encrypted;
    if (conversation?.isDm == true && body.isNotEmpty) {
      encrypted = await ref
          .read(messageVaultProvider)
          .encryptExisting(
            conversationId: convId,
            text: body,
            currentUserId: state.currentUserId,
          );
    }
    var msg = await repo.patchMessage(
      messageId,
      encrypted == null ? body : '',
      encryptedBody: encrypted?.encryptedBody,
      encryptionNonce: encrypted?.nonce,
      encryptionVersion: encrypted == null ? null : 1,
      encryptionKeyVersion: encrypted?.keyVersion,
    );
    if (msg.isEncrypted) {
      msg = await ref
          .read(messageVaultProvider)
          .decryptMessage(msg, state.currentUserId);
    }
    updateFeedMessage(convId, msg);
    final thread = msg.parentId ?? state.threadRootId;
    if (thread != null) {
      updateFeedMessage(convId, msg, threadRootId: thread);
    }
    if (msg.parentId != null) patchThreadReply(msg.parentId!, msg);
  }

  Future<void> deleteMessage(String messageId) async {
    await repo.deleteMessage(messageId);
    final convId = state.activeConversationId;
    if (convId == null) return;
    removeFeedMessage(convId, messageId);
    final thread = state.threadRootId;
    if (thread != null) {
      removeFeedMessage(convId, messageId, threadRootId: thread);
    }
    for (final rootId in state.threadRepliesByRoot.keys) {
      markThreadReplyDeleted(rootId, messageId);
    }
  }

  Future<int> forwardMessage({
    required String messageId,
    List<String>? conversationIds,
    List<String>? userIds,
    String? caption,
  }) => repo.forwardMessage(
    messageId: messageId,
    conversationIds: conversationIds,
    userIds: userIds,
    caption: caption,
  );

  /// Local history answers first so results appear with no round trip, then
  /// the server result replaces them — it reaches further back than the disk
  /// window and, unlike the local index, can match inside an E2EE DM.
  Future<void> searchMessages(String q) async {
    state = state.copyWith(searchQuery: q, searchLoading: true);
    final store = (this as _ChatCacheMixin).messageStore;
    final local = await store.search(q);
    if (state.searchQuery != q) return;
    if (local.isNotEmpty) {
      state = state.copyWith(searchResults: local, searchLoading: false);
    }
    try {
      final results = await repo.searchMessages(q);
      if (state.searchQuery != q) return;
      state = state.copyWith(searchResults: results, searchLoading: false);
    } catch (_) {
      // Offline: whatever the local index found stands as the answer.
      if (state.searchQuery != q) return;
      state = state.copyWith(searchResults: local, searchLoading: false);
    }
  }

  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) => repo.presignAttachment(
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

  /// Removes a DM from just this device's list ("delete for me") — it
  /// reappears once the peer sends a new message. Removed optimistically;
  /// on failure the next silent sidebar refresh brings it back.
  Future<void> hideDm(String conversationId) async {
    state = state.copyWith(
      dms: state.dms.where((c) => c.id != conversationId).toList(),
    );
    try {
      await repo.hideDm(conversationId);
    } catch (_) {
      await (this as ChatNotifier).fetchSidebar(silent: true);
    }
  }

  Future<void> deleteChannel(String channelId) async {
    await repo.deleteChannel(channelId);
    await (this as ChatNotifier).fetchSidebar(silent: true);
  }
}
