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
    // Encryption follows the ROW being edited, inside a conversation that may
    // hold a key at all — never `isDm`. A personal group is E2EE too, and the
    // DM test sent plaintext for one of its ciphertext rows, which the server
    // refuses ('encrypted messages require an encrypted edit').
    final existing = _findEditableMessage(convId, messageId);
    final secure =
        (conversation?.isEncrypted ?? false) &&
        (existing?.isEncrypted ?? false);
    EncryptedDmPayload? encrypted;
    if (secure && body.isNotEmpty) {
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

  /// The stored copy of a message, from the main feed or the open thread —
  /// whether it is ciphertext is what decides how an edit is sent.
  ChatMessage? _findEditableMessage(String convId, String messageId) {
    final feeds = [
      state.feedFor(convId),
      if (state.threadRootId != null)
        state.feedFor(convId, threadRootId: state.threadRootId),
    ];
    for (final feed in feeds) {
      for (final message in feed.messages) {
        if (message.id == messageId) return message;
      }
    }
    return null;
  }

  Future<void> deleteMessage(String messageId) async {
    final deletingConversation = state.activeConversationId;
    await repo.deleteMessage(messageId);
    if (deletingConversation != null) {
      await ref
          .read(chatMessageStoreProvider)
          .deletions
          .rememberMessage(deletingConversation, messageId);
    }
    await ref.read(attachmentSweeperProvider).onMessageDeleted(messageId);
    await ref.read(chatMessageStoreProvider).remove(messageId);
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
    List<Map<String, dynamic>>? targets,
    String? caption,
  }) => repo.forwardMessage(
    messageId: messageId,
    conversationIds: conversationIds,
    userIds: userIds,
    targets: targets,
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
    String contentType, {
    ProgressCallback? onProgress,
  }) async {
    final dio = Dio();
    await dio.put(
      presign.uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
      onSendProgress: onProgress,
    );
  }

  Future<void> uploadAttachmentFile(
    ChatPresignResult presign,
    File file,
    String contentType,
    int sizeBytes, {
    ProgressCallback? onProgress,
  }) async {
    final dio = Dio();
    await dio.put(
      presign.uploadUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': contentType,
          Headers.contentLengthHeader: sizeBytes,
        },
      ),
      onSendProgress: onProgress,
    );
  }

  Future<void> discardUpload(String conversationId, String fileUrl) =>
      repo.discardUpload(conversationId, fileUrl);

  Future<void> muteConversation(String id, bool muted) async {
    await repo.muteConversation(id, muted);
    state = state.copyWith(
      dms: patchList(state.dms, id, muted: muted),
      channels: patchList(state.channels, id, muted: muted),
    );
  }

  /// Pin or unpin for this account. The server owns the four-pin cap and
  /// answers a fifth with 409 `chat_pin_limit`, which is left to propagate:
  /// the sheet turns it into one sentence, and patching state optimistically
  /// here would show a pin the server refused.
  Future<void> pinConversation(String id, bool pinned) async {
    await repo.pinConversation(id, pinned);
    state = state.copyWith(
      dms: patchList(state.dms, id, pinned: pinned),
      channels: patchList(state.channels, id, pinned: pinned),
    );
  }

  /// Name, description, picture, banner in one call — for every group, a
  /// converted workspace channel included.
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

  /// Drops every in-memory trace of a conversation that was just deleted.
  ///
  /// The wipe on disk is not enough on its own: feeds live in state keyed by
  /// conversation id, so reopening the same chat in the same session — which is
  /// exactly what happens when you delete it and then message the person again
  /// — re-rendered the whole history straight out of memory, with nothing left
  /// on the server or the disk to explain where it came from.
  ///
  /// Thread feeds are keyed `<conversationId>:thread:<rootId>`, so both maps
  /// are filtered by prefix rather than by an exact key.
  void _forgetConversationInMemory(String conversationId) {
    if (conversationId.isEmpty) return;
    bool belongs(String key) =>
        key == conversationId || key.startsWith('$conversationId:');
    state = state.copyWith(
      dms: state.dms.where((c) => c.id != conversationId).toList(),
      channels: state.channels.where((c) => c.id != conversationId).toList(),
      feeds: {
        for (final entry in state.feeds.entries)
          if (!belongs(entry.key)) entry.key: entry.value,
      },
      threadRepliesByRoot: {
        for (final entry in state.threadRepliesByRoot.entries)
          if (entry.value.any((m) => m.conversationId != conversationId))
            entry.key: entry.value
                .where((m) => m.conversationId != conversationId)
                .toList(),
      },
      searchResults: state.searchResults
          .where((m) => m.conversationId != conversationId)
          .toList(),
    );
  }

  Future<void> leaveChannel(String channelId) async {
    await repo.leaveChannel(channelId);
    _forgetConversationInMemory(channelId);
    await wipeConversationLocally(ref, channelId, ownerId: state.currentUserId);
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
    _forgetConversationInMemory(conversationId);
    await wipeConversationLocally(
      ref,
      conversationId,
      ownerId: state.currentUserId,
    );
    await syncChatDeletions(ref, state.currentUserId);
  }

  Future<void> deleteChannel(String channelId) async {
    await repo.deleteChannel(channelId);
    _forgetConversationInMemory(channelId);
    await wipeConversationLocally(ref, channelId, ownerId: state.currentUserId);
    await (this as ChatNotifier).fetchSidebar(silent: true);
  }
}
