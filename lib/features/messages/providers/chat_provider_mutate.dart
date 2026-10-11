part of 'chat_provider.dart';

mixin _ChatMutateMixin
    on Notifier<ChatState>, _ChatActionsMixin, _ChatFeedEditMixin {
  @override
  ChatRepository get repo;

  /// Drawn locally first, sent second — the server's answer (or the private
  /// op) then replaces the guess, and a refusal puts the old set back.
  Future<void> toggleReaction(String messageId, String emoji) async {
    final convId = state.activeConversationId;
    final thread = state.threadRootId;
    final private = _privateTarget(messageId);
    final before = convId == null
        ? null
        : _findEditableMessage(convId, messageId)?.reactions;
    void show(List<ChatReactionGroup> reactions) {
      if (convId == null) return;
      updateFeedReactions(convId, messageId, reactions);
      if (thread != null) {
        updateFeedReactions(convId, messageId, reactions, threadRootId: thread);
      }
    }

    if (before != null) {
      final me = state.currentUserId;
      final mine = before.any(
        (g) =>
            g.emoji == emoji &&
            (g.reactedByMe || g.users.any((u) => u.userId == me)),
      );
      show(
        applyPrivateReaction(
          before,
          userId: me,
          currentUserId: me,
          emoji: emoji,
          reacted: !mine,
        ),
      );
    }
    try {
      if (private != null) {
        // `private` was read before the local draw, so the op still says
        // which way to flip; applying it over the guess is idempotent.
        await (this as _ChatPrivateOpsMixin).reactPrivately(private, emoji);
        return;
      }
      show(await repo.toggleReaction(messageId, emoji));
    } catch (_) {
      if (before != null) show(before);
      rethrow;
    }
  }

  /// The new text is drawn at once; the request (and the sealing before it)
  /// runs behind it, and a refusal puts the old message back.
  Future<void> editMessage(String messageId, String body) async {
    final convId = state.activeConversationId;
    if (convId == null) return;
    final existing = _findEditableMessage(convId, messageId);
    void show(ChatMessage m) {
      updateFeedMessage(convId, m);
      final thread = m.parentId ?? state.threadRootId;
      if (thread != null) updateFeedMessage(convId, m, threadRootId: thread);
      if (m.parentId != null) patchThreadReply(m.parentId!, m);
    }

    if (existing != null) {
      show(
        existing.copyWith(
          body: body,
          editedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    }
    try {
      if (existing != null && existing.privateChat) {
        await (this as _ChatPrivateOpsMixin).editPrivately(existing, body);
        return;
      }
      show(await _sendEdit(convId, messageId, body, existing));
    } catch (_) {
      if (existing != null) show(existing);
      rethrow;
    }
  }

  Future<ChatMessage> _sendEdit(
    String convId,
    String messageId,
    String body,
    ChatMessage? existing,
  ) async {
    final conversation = state.conversationById(convId);
    // Encryption follows the ROW being edited, inside a conversation that may
    // hold a key at all — never `isDm`. A personal group is E2EE too, and the
    // DM test sent plaintext for one of its ciphertext rows, which the server
    // refuses ('encrypted messages require an encrypted edit').
    // A ciphertext row is edited as ciphertext whatever the list calls its
    // conversation now. With no stored copy to read, the chat decides.
    final secure =
        existing?.isEncrypted ??
        mustSealChat(
          pinned: await ref
              .read(encryptionPinsProvider)
              .isPinned(state.currentUserId, convId),
          conversation: conversation,
        );
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
    final msg = await repo.patchMessage(
      messageId,
      encrypted == null ? body : '',
      encryptedBody: encrypted?.encryptedBody,
      encryptionNonce: encrypted?.nonce,
      encryptionVersion: encrypted == null ? null : 1,
      encryptionKeyVersion: encrypted?.keyVersion,
    );
    if (!msg.isEncrypted) return msg;
    return ref
        .read(messageVaultProvider)
        .decryptMessage(msg, state.currentUserId);
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

  Future<void> deleteMessage(String messageId) => _removeThen(messageId, () {
    final private = _privateTarget(messageId);
    if (private != null) {
      return (this as _ChatPrivateOpsMixin).deletePrivately(private);
    }
    return repo.deleteMessage(messageId);
  });

  /// "Delete for me": gone on this account's devices, untouched for the rest
  /// of the conversation. Locally it is the same forgetting as a delete.
  ///
  /// A private-chat message is usually already gone from the server (0160),
  /// so the server half is best effort there and the local forget is what
  /// counts.
  Future<void> hideMessage(String messageId) => _removeThen(
    messageId,
    () async {
      if (_privateTarget(messageId) == null) return repo.hideMessage(messageId);
      try {
        await repo.hideMessage(messageId);
      } catch (_) {}
    },
  );

  /// The row leaves the screen at once; the stored copy and its files are
  /// only wiped after [send] succeeds, so a refusal can put the row back.
  Future<void> _removeThen(
    String messageId,
    Future<void> Function() send,
  ) async {
    final convId = state.activeConversationId;
    final thread = state.threadRootId;
    final inMain = convId == null
        ? null
        : state
              .feedFor(convId)
              .messages
              .where((m) => m.id == messageId)
              .firstOrNull;
    final inThread = convId == null || thread == null
        ? null
        : state
              .feedFor(convId, threadRootId: thread)
              .messages
              .where((m) => m.id == messageId)
              .firstOrNull;
    // Read before the row leaves: [send] looks the target up in the feed.
    final request = send();
    if (convId != null) {
      removeFeedMessage(convId, messageId);
      if (thread != null) {
        removeFeedMessage(convId, messageId, threadRootId: thread);
      }
    }
    try {
      await request;
    } catch (_) {
      if (convId != null) {
        if (inMain != null) appendFeedMessage(convId, inMain);
        if (inThread != null) {
          appendFeedMessage(convId, inThread, threadRootId: thread);
        }
      }
      rethrow;
    }
    await _forgetMessage(messageId);
  }

  /// The loaded private-chat message [messageId] names in the open
  /// conversation, or null for an ordinary one — which keeps the ordinary
  /// endpoints.
  ChatMessage? _privateTarget(String messageId) {
    final convId = state.activeConversationId;
    if (convId == null) return null;
    final found = _findEditableMessage(convId, messageId);
    return (found?.privateChat ?? false) ? found : null;
  }

  Future<void> _forgetMessage(String messageId) async {
    final deletingConversation = state.activeConversationId;
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

  /// Local history answers first so results appear with no round trip.
  /// One character is enough on-device; the server is only asked at two or more
  /// so a single keystroke does not fan out a network search.
  /// [conversationId] scopes the search to one chat (its details screen).
  /// The server index reads plaintext only, so its answer is MERGED with the
  /// on-device hits rather than replacing them — an encrypted DM or group
  /// exists only in the local, vault-decrypted half.
  Future<void> searchMessages(String q, {String? conversationId}) async {
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
    ).search(q, conversationId: conversationId);
    if (state.searchQuery != q) return;
    if (q.trim().length < 2) {
      state = state.copyWith(searchResults: local, searchLoading: false);
      return;
    }
    if (local.isNotEmpty) {
      state = state.copyWith(searchResults: local, searchLoading: false);
    }
    try {
      final remote = (await repo.searchMessages(q)).where(
        (m) => conversationId == null || m.conversationId == conversationId,
      );
      if (state.searchQuery != q) return;
      final merged =
          <String, ChatMessage>{
              for (final m in remote) m.id: m,
              for (final m in local) m.id: m,
            }.values.toList()
            ..sort((a, b) => messageTimeMs(b).compareTo(messageTimeMs(a)));
      state = state.copyWith(searchResults: merged, searchLoading: false);
    } catch (_) {
      // Offline: whatever the local index found stands as the answer.
      if (state.searchQuery != q) return;
      state = state.copyWith(searchResults: local, searchLoading: false);
    }
  }

  /// Reserves an upload slot for a message attachment.
  ///
  /// In an encrypted conversation the file is encrypted on this phone before
  /// it leaves (server 0168): the slot is asked for as ciphertext, and the
  /// upload helpers below and [sendMessage] pick the key up by the returned
  /// public URL — callers change nothing. Pass [plain] for an object that is
  /// not a message attachment and has to stay readable by URL: a group's
  /// photo or banner, a feed's picture.
  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
    bool plain = false,
  }) async {
    final secret = plain
        ? null
        : await sealedUploadSecret(
            ref,
            state.conversationById(conversationId),
            userId: state.currentUserId,
            conversationId: conversationId,
            contentType: contentType,
            fileName: fileName,
            sizeBytes: sizeBytes,
          );
    if (secret == null) {
      return repo.presignAttachment(
        conversationId,
        contentType: contentType,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );
    }
    final presign = await repo.presignAttachment(
      conversationId,
      contentType: secret.wireType,
      fileName: secret.wireName,
      sizeBytes: secret.cipherSize,
      encrypted: true,
    );
    SealedUploads.register(presign.publicUrl, secret);
    return presign;
  }

  Future<void> uploadAttachmentBytes(
    ChatPresignResult presign,
    List<int> bytes,
    String contentType, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final secret = SealedUploads.sizedFor(presign.publicUrl, bytes.length);
    if (secret != null) {
      return SealedUploads.putBytes(
        presign.uploadUrl,
        bytes,
        secret,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
    final dio = Dio();
    await dio.put(
      presign.uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    );
  }

  Future<void> uploadAttachmentFile(
    ChatPresignResult presign,
    File file,
    String contentType,
    int sizeBytes, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final secret = SealedUploads.sizedFor(
      presign.publicUrl,
      await file.length(),
    );
    if (secret != null) {
      return SealedUploads.putFile(
        presign.uploadUrl,
        file,
        secret,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
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
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    );
  }

  Future<void> discardUpload(String conversationId, String fileUrl) {
    SealedUploads.forget(fileUrl);
    return repo.discardUpload(conversationId, fileUrl);
  }

  /// Mute with [choice], or unmute when null. Drawn from the choice at once,
  /// then patched from the server's answer, so a timed mute caches the
  /// server's end time; a refusal restores the row.
  Future<void> setMute(String id, MuteChoice? choice) async {
    void show(MuteResult result) {
      List<ChatConversation> apply(List<ChatConversation> list) => [
        for (final c in list)
          c.id != id
              ? c
              : c.copyWith(
                  muted: result.muted,
                  mutedUntil: result.until,
                  clearMutedUntil: result.until == null,
                  muteMode: result.mode,
                ),
      ];
      state = state.copyWith(
        dms: apply(state.dms),
        channels: apply(state.channels),
      );
    }

    final before = state.conversationById(id);
    final length = choice?.duration;
    show(
      choice == null
          ? MuteResult.unmuted
          : MuteResult(
              muted: true,
              until:
                  choice.until ??
                  (length == null ? null : DateTime.now().add(length)),
              mode: choice.mentionsOnly ? 'mentions' : 'all',
            ),
    );
    try {
      show(await repo.setMute(id, choice));
    } catch (_) {
      if (before != null) {
        show(
          MuteResult(
            muted: before.muted,
            until: before.mutedUntil,
            mode: before.muteMode,
          ),
        );
      }
      rethrow;
    }
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
    (this as _ChatOlderTopMixin).forgetOlderPaging(conversationId);
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
