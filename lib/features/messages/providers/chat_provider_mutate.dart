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
  /// an active workspace permits a server result to replace them. Personal-only
  /// users search their device history only.
  Future<void> searchMessages(String q) async {
    state = state.copyWith(searchQuery: q, searchLoading: true);
    final store = (this as _ChatCacheMixin).messageStore;
    final vault = ref.read(messageVaultProvider);
    var userId = state.currentUserId;
    if (userId.isEmpty) userId = await (this as ChatNotifier).localUserId();
    final local = await LocalMessageSearch(
      store,
      vault.isUnlocked && userId.isNotEmpty
          ? (messages) async {
              final clear = await vault.decryptMessages(messages, userId);
              return clear
                  .where(
                    (message) =>
                        message.body != 'Encrypted message' &&
                        message.body != 'Unable to decrypt this message',
                  )
                  .toList();
            }
          : (_) async => const [],
    ).search(q);
    if (state.searchQuery != q) return;
    if (local.isNotEmpty) {
      state = state.copyWith(searchResults: local, searchLoading: false);
    }
    if (!ref.read(chatEnabledProvider)) {
      state = state.copyWith(searchResults: local, searchLoading: false);
      return;
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

  /// Personal groups only — name, description, picture, banner in one call. A
  /// workspace channel renames through [renameChannel].
  Future<ChatConversation> updateGroupInfo(
    String id, {
    String? name,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
  }) async {
    final updated = await repo.updateGroupInfo(
      id,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
    );
    upsertChannel(updated);
    return updated;
  }

  Future<void> setGroupMemberRole(String id, String userId, String role) =>
      repo.setGroupMemberRole(id, userId, role);

  Future<void> removeGroupMember(String id, String userId) =>
      repo.removeGroupMember(id, userId);

  Future<List<ChatMember>> listChannelMembers(String channelId) =>
      repo.listChannelMembers(channelId);

  Future<void> addChannelMember(String channelId, String userId) =>
      repo.addChannelMember(channelId, userId);

  Future<void> leaveChannel(String channelId) async {
    await repo.leaveChannel(channelId);
    await wipeConversationLocally(ref, channelId);
    await (this as ChatNotifier).fetchSidebar(silent: true);
  }

  /// Deletes a DM for this account, everywhere it is stored.
  ///
  /// The server stops serving those messages to this user permanently and
  /// physically deletes whatever the peer has also deleted; the local drift
  /// copy and the downloaded files go here. The conversation still returns to
  /// the sidebar if the peer writes again — empty, with none of the history
  /// back.
  ///
  /// The local wipe runs only after the server confirms. Doing it first would
  /// destroy the device's copy of a chat that is still on the server whenever
  /// the request fails.
  Future<void> hideDm(String conversationId) async {
    state = state.copyWith(
      dms: state.dms.where((c) => c.id != conversationId).toList(),
    );
    try {
      await repo.hideDm(conversationId);
    } catch (_) {
      await (this as ChatNotifier).fetchSidebar(silent: true);
      return;
    }
    await wipeConversationLocally(ref, conversationId);
  }

  Future<void> deleteChannel(String channelId) async {
    await repo.deleteChannel(channelId);
    await wipeConversationLocally(ref, channelId);
    await (this as ChatNotifier).fetchSidebar(silent: true);
  }
}
