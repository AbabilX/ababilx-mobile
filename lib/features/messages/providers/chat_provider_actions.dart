part of 'chat_provider.dart';

mixin _ChatActionsMixin
    on Notifier<ChatState>, _ChatPatchMixin, _ChatFeedMixin {
  @override
  ChatRepository get repo;

  void incrementThreadCount(String conversationId, String rootId) {
    final key = feedKey(conversationId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages
            .map(
              (m) => m.id == rootId
                  ? m.copyWith(threadCount: m.threadCount + 1)
                  : m,
            )
            .toList(),
      ),
    );
  }

  /// Returns false if [msg] was already in the thread (idempotent for send+WS).
  bool appendThreadReply(String rootId, ChatMessage msg) {
    final list = state.threadRepliesByRoot[rootId] ?? [];
    if (list.any((m) => m.id == msg.id)) return false;
    state = state.copyWith(
      threadRepliesByRoot: {
        ...state.threadRepliesByRoot,
        rootId: [...list, msg],
      },
    );
    return true;
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
            .map(
              (m) => m.id == messageId
                  ? m.copyWith(
                      deletedAt: DateTime.now().toUtc().toIso8601String(),
                      body: '',
                    )
                  : m,
            )
            .toList(),
      },
    );
  }

  Future<ChatMessage?> sendMessage({
    String? conversationId,
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
  }) async {
    final convId = conversationId ?? state.activeConversationId;
    if (convId == null) return null;

    // ── Step 1: Build a pending message and show it instantly in the UI ──────
    final clientRef = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    // E2EE binds the sender UUID into the AAD, so an empty id here would seal a
    // message nobody — including this device — can ever open again.
    final String currentUser;
    try {
      currentUser = await (this as ChatNotifier).ensureCurrentUserId();
    } catch (_) {
      return null;
    }
    // Look up the user's display name and avatar from any conversation they appear in.
    final conv = state.conversationById(convId);
    final pendingMsg = ChatMessage(
      id: clientRef,
      conversationId: convId,
      userId: currentUser,
      body: body,
      parentId: parentId,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      sendStatus: MessageSendStatus.sending,
      clientRef: clientRef,
      pendingAttachments: List.unmodifiable(attachments),
      pendingParentId: parentId,
      pendingMentionedUserIds: List.unmodifiable(mentionedUserIds),
      // Show the sender's own name if we can resolve it from the DM peer info.
      userName: conv?.peerUserName,
    );

    // Inject into feed immediately so user sees it at once.
    _appendPendingMessage(convId, pendingMsg, parentId: parentId);
    // Update sidebar preview with optimistic body.
    applyIncomingMessage(convId, pendingMsg, bumpUnread: false);

    try {
      EncryptedDmPayload? encrypted;
      if (conv?.isDm == true && body.isNotEmpty) {
        final peerId = conv?.peerUserId;
        if (peerId == null || peerId.isEmpty) {
          throw StateError('Secure DM recipient is unavailable');
        }
        encrypted = await ref
            .read(messageVaultProvider)
            .encryptNew(
              conversationId: convId,
              text: body,
              currentUserId: currentUser,
              peerUserId: peerId,
            );
      }
      // ── Step 2: Fire the actual network call ─────────────────────────────
      var msg = await repo.sendMessage(
        convId,
        body: encrypted == null ? body : '',
        encryptedBody: encrypted?.encryptedBody,
        encryptionNonce: encrypted?.nonce,
        encryptionVersion: encrypted == null ? null : 1,
        encryptionKeyVersion: encrypted?.keyVersion,
        parentId: parentId,
        attachments: attachments,
        mentionedUserIds: mentionedUserIds,
      );
      if (msg.isEncrypted) {
        msg = await ref
            .read(messageVaultProvider)
            .decryptMessage(msg, currentUser);
      }
      // ── Step 3: Replace the pending bubble with the confirmed message ─────
      _replacePendingMessage(convId, clientRef, msg, parentId: parentId);
      return msg;
    } catch (_) {
      // ── Step 4: Mark the bubble as failed so user can retry ───────────────
      _markPendingFailed(convId, clientRef, parentId: parentId);
      return null;
    }
  }

  /// Re-sends a message that previously failed. Looks up the pending data
  /// stored on the [ChatMessage] itself and calls [sendMessage] again.
  Future<void> retrySend(ChatMessage failedMsg) async {
    if (failedMsg.sendStatus != MessageSendStatus.failed) return;
    final convId = failedMsg.conversationId;
    if (convId.isEmpty) return;

    // Remove the failed bubble first — sendMessage will create a fresh pending one.
    _removePendingFromFeed(convId, failedMsg.id, parentId: failedMsg.parentId);

    await sendMessage(
      conversationId: convId,
      body: failedMsg.body,
      attachments: failedMsg.pendingAttachments,
      mentionedUserIds: failedMsg.pendingMentionedUserIds,
      parentId: failedMsg.pendingParentId,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _appendPendingMessage(
    String convId,
    ChatMessage msg, {
    String? parentId,
  }) {
    if (parentId != null) {
      _appendToFeed(convId, msg, threadRootId: parentId);
      if (appendThreadReply(parentId, msg)) {
        incrementThreadCount(convId, parentId);
      }
    } else {
      _appendToFeed(convId, msg);
    }
  }

  /// Forcibly appends [msg] to the feed even if it has never been fetched —
  /// needed for the local pending bubble (we know it's valid).
  void _appendToFeed(String convId, ChatMessage msg, {String? threadRootId}) {
    final key = feedKey(convId, threadRootId: threadRootId);
    final feed =
        state.feeds[key] ??
        ChatFeed(fetchedAt: DateTime.now().millisecondsSinceEpoch);
    if (feed.messages.any((m) => m.id == msg.id)) return;
    setFeed(key, feed.copyWith(messages: [...feed.messages, msg]));
  }

  void _replacePendingMessage(
    String convId,
    String clientRef,
    ChatMessage confirmed, {
    String? parentId,
  }) {
    final key = feedKey(convId, threadRootId: parentId);
    final feed = state.feeds[key];
    if (feed != null) {
      final alreadyInFeed = feed.messages.any((m) => m.id == confirmed.id);
      final hasPending = feed.messages.any(
        (m) => m.clientRef == clientRef || m.id == clientRef,
      );

      if (alreadyInFeed) {
        // If WS already added confirmed message, filter out the pending message
        setFeed(
          key,
          feed.copyWith(
            messages: feed.messages
                .where((m) => m.clientRef != clientRef && m.id != clientRef)
                .toList(),
          ),
        );
      } else if (hasPending) {
        // Replace pending with confirmed
        setFeed(
          key,
          feed.copyWith(
            messages: feed.messages.map((m) {
              if (m.clientRef == clientRef || m.id == clientRef) {
                return confirmed;
              }
              return m;
            }).toList(),
          ),
        );
      } else {
        // Feed is loaded but pending was lost, append confirmed
        setFeed(key, feed.copyWith(messages: [...feed.messages, confirmed]));
      }
    }

    if (parentId != null) {
      patchThreadReply(parentId, confirmed);
    }
    // Update sidebar with confirmed message body.
    applyIncomingMessage(convId, confirmed, bumpUnread: false);
  }

  void _markPendingFailed(String convId, String clientRef, {String? parentId}) {
    _patchInFeed(
      convId,
      (m) => m.clientRef == clientRef
          ? m.copyWith(sendStatus: MessageSendStatus.failed)
          : m,
      threadRootId: parentId,
    );
  }

  void _removePendingFromFeed(
    String convId,
    String pendingId, {
    String? parentId,
  }) {
    final key = feedKey(convId, threadRootId: parentId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.where((m) => m.id != pendingId).toList(),
      ),
    );
  }

  /// Applies [mapper] to every message in the feed for [convId].
  void _patchInFeed(
    String convId,
    ChatMessage Function(ChatMessage) mapper, {
    String? threadRootId,
  }) {
    final key = feedKey(convId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(key, feed.copyWith(messages: feed.messages.map(mapper).toList()));
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
