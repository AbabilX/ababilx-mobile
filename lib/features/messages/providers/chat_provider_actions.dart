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
    String? clientMessageId,
  }) async {
    final convId = conversationId ?? state.activeConversationId;
    if (convId == null) return null;

    // ── Step 1: Build a pending message and show it instantly in the UI ──────
    final clientRef = clientMessageId ?? newChatClientMessageId();
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
      // Persist before the network call — even a send that never gets to
      // try (app killed offline) must survive as a retryable outbox row.
      await (this as _ChatOutboxMixin).persistOutbox(
        convId,
        pendingMsg,
        encrypted: encrypted,
      );
      // ── Step 2: Fire the actual network call ─────────────────────────────
      var msg = await repo.sendMessage(
        convId,
        clientMessageId: clientRef,
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
      (this as _ChatOutboxMixin).removeFromOutboxAsync(clientRef);
      _replacePendingMessage(convId, clientRef, msg, parentId: parentId);
      return msg;
    } catch (_) {
      // ── Step 4: Mark the bubble as failed so user can retry ───────────────
      // When persistence succeeded, its outbox row stays as the retry record.
      // A storage failure never reaches the network, so no duplicate is possible.
      _markPendingFailed(convId, clientRef, parentId: parentId);
      return null;
    }
  }

  /// Re-sends a message that previously failed. Looks up the pending data
  /// stored on the [ChatMessage] itself and calls [sendMessage] again.
  ///
  /// Refuses a DM bubble still showing the vault's locked placeholder — its
  /// `body` is not the real text, so sending it would leak that placeholder
  /// string as the message. [redecryptFailedMessages] clears this once the
  /// vault unlocks.
  Future<void> retrySend(ChatMessage failedMsg) async {
    if (failedMsg.sendStatus != MessageSendStatus.failed) return;
    if (isLockedFailedMessage(failedMsg)) return;
    final convId = failedMsg.conversationId;
    if (convId.isEmpty) return;

    // Keep the same client id: if the server committed but its response was
    // lost, this retry returns the original row instead of duplicating it.
    _removePendingFromFeed(convId, failedMsg.id, parentId: failedMsg.parentId);

    await sendMessage(
      conversationId: convId,
      clientMessageId: failedMsg.clientRef,
      body: failedMsg.body,
      attachments: failedMsg.pendingAttachments,
      mentionedUserIds: failedMsg.pendingMentionedUserIds,
      parentId: failedMsg.pendingParentId,
    );
  }

  /// Automatically flushes all failed messages across active feeds when
  /// network restores — including ones reloaded from a previous session by
  /// [hydrateOutboxMessages]. Locked DM bubbles are skipped; they flush once
  /// [redecryptFailedMessages] resolves their real text after vault unlock.
  Future<void> retryPendingMessages() async {
    for (final entry in state.feeds.entries) {
      final feed = entry.value;
      final failedList = feed.messages
          .where(
            (m) =>
                m.sendStatus == MessageSendStatus.failed &&
                !isLockedFailedMessage(m),
          )
          .toList();
      for (final msg in failedList) {
        await retrySend(msg);
      }
    }
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
    // Reading it here clears it there: a tray entry for messages the user is
    // looking at right now is noise, and its stacked thread is stale.
    unawaited(
      ChatNotificationPresenter.dismiss(
        ref.read(localNotificationsProvider),
        conversationId,
      ),
    );
    try {
      await repo.markRead(conversationId);
    } catch (_) {}
    final ids = <String>{};
    for (final entry in state.feeds.entries) {
      if (entry.key == conversationId ||
          entry.key.startsWith('$conversationId:thread:')) {
        ids.addAll(entry.value.messages.map((message) => message.id));
      }
    }
    if (ids.isNotEmpty) {
      unawaited(
        repo.acknowledgeMessages('read', ids.toList()).catchError((_) {}),
      );
    }
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

  Future<ChatConversation> createPersonalGroup(
    String name,
    List<String> memberIds,
  ) async {
    final group = await repo.createPersonalGroup(name, memberIds);
    upsertChannel(group);
    return group;
  }
}
