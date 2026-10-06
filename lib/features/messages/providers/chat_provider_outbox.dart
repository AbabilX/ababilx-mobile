part of 'chat_provider.dart';

/// Durable send outbox: an outbound message is on disk before the request is
/// even attempted, so a kill mid-send never loses it. Separate from
/// [_ChatCacheMixin] because it owns writes the user made, not a copy of
/// server state that can always be refetched.
mixin _ChatOutboxMixin on Notifier<ChatState>, _ChatFeedMixin {
  ChatOutboxCache get outboxCache;

  // ─── Outbox (durable — see PendingOutboxMessages) ──────────────────────────

  /// Writes the conversation-encrypted [pendingMsg] to durable history
  /// before the network call is even made, so a send survives an app kill
  /// regardless of whether it ever gets to try. Pass [encrypted] for a DM
  /// send — its ciphertext is stored instead of [pendingMsg.body], never the
  /// plaintext. This future must complete before the caller starts the
  /// network request.
  Future<void> persistOutbox(
    String conversationId,
    ChatMessage pendingMsg, {
    EncryptedDmPayload? encrypted,
  }) async {
    final disk = encrypted == null
        ? pendingMsg
        : pendingMsg.copyWith(
            body: '',
            encryptedBody: encrypted.encryptedBody,
            encryptionNonce: encrypted.nonce,
            encryptionVersion: 1,
            encryptionKeyVersion: encrypted.keyVersion,
          );
    await (this as _ChatCacheMixin).persistFeed([disk]);
  }

  void removeFromOutboxAsync(String clientRef) {
    outboxCache.remove(clientRef).ignore();
  }

  Future<void> stageOutbox(ChatMessage message) async {
    final payload = await ref.read(localOutboxCipherProvider).seal(message);
    if (!(this as _ChatCacheMixin).messageStore.deletions.allows(message)) {
      throw StateError('This pending message was deleted');
    }
    await outboxCache.save(
      clientRef: message.clientRef ?? message.id,
      conversationId: message.conversationId,
      body: '',
      parentId: message.parentId,
      encryptedBody: payload,
    );
  }

  Future<void> settleOutbox(ChatMessage message) async {
    final clientRef = message.clientRef;
    if (clientRef == null || message.isPending) return;
    await ref
        .read(composerDraftStoreProvider)
        .completeSend(
          message.userId,
          message.conversationId,
          clientRef,
          parentId: message.parentId,
        );
    await outboxCache.remove(clientRef);
  }

  /// Reloads every outstanding send left over from a previous session and
  /// re-injects it as a failed bubble in its conversation's feed, so it
  /// shows up as "tap to retry" immediately — and so [retryPendingMessages]
  /// (fired on the next WS reconnect) picks it up without the user having to
  /// open that conversation first. Device-sealed outbox entries hold the full
  /// retry payload; old conversation-encrypted history/outbox rows remain
  /// readable for upgrades from earlier app versions.
  Future<void> hydrateOutboxMessages() async {
    final userId = state.currentUserId;
    if (userId.isEmpty) return;
    final vault = ref.read(messageVaultProvider);
    final seen = <String>{};

    Future<void> inject(ChatMessage raw) async {
      var msg = raw.isPending
          ? raw.copyWith(sendStatus: MessageSendStatus.failed)
          : raw;
      if (msg.isEncrypted && vault.isUnlocked) {
        msg = await vault.decryptMessage(msg, userId);
      }
      final identity = msg.clientRef ?? msg.id;
      if (identity.isEmpty || seen.contains(identity)) return;
      final key = feedKey(msg.conversationId, threadRootId: msg.parentId);
      // fetchedAt stays 0: this feed holds one unsent bubble, not a page of
      // history, and opening it must still read the disk and the server.
      final feed = state.feeds[key] ?? const ChatFeed();
      if (feed.messages.any(
        (m) =>
            m.id == msg.id || (m.clientRef != null && m.clientRef == identity),
      )) {
        seen.add(identity);
        return;
      }
      setFeed(
        key,
        feed.copyWith(messages: canonicalChatMessages([...feed.messages, msg])),
      );
      seen.add(identity);
    }

    final entries = await outboxCache.readAll();
    for (final entry in entries.where((e) => e.isLocal)) {
      if (!(this as _ChatCacheMixin).messageStore.deletions.allowsTime(
        entry.conversationId,
        entry.createdAtMs * 1000,
        pending: true,
      )) {
        continue;
      }
      try {
        final message = await ref
            .read(localOutboxCipherProvider)
            .open(
              entry.encryptedBody!,
              userId,
              entry.conversationId,
              entry.clientRef,
            );
        await inject(message);
      } catch (_) {
        // Locked/unavailable secure storage: retain the envelope for next boot.
      }
    }
    for (final msg
        in await (this as _ChatCacheMixin).messageStore.listUnsent()) {
      await inject(msg);
    }
    for (final entry in entries) {
      if (entry.isLocal) continue;
      if (seen.contains(entry.clientRef)) continue;
      var msg = ChatMessage(
        id: entry.clientRef,
        conversationId: entry.conversationId,
        userId: userId,
        body: entry.isEncrypted ? 'Encrypted message' : entry.body,
        parentId: entry.parentId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          entry.createdAtMs,
        ).toUtc().toIso8601String(),
        sendStatus: MessageSendStatus.failed,
        clientRef: entry.clientRef,
        encryptedBody: entry.encryptedBody,
        encryptionNonce: entry.encryptionNonce,
        encryptionVersion: entry.isEncrypted ? 1 : null,
        encryptionKeyVersion: entry.encryptionKeyVersion,
        pendingAttachments: entry.attachments,
        pendingParentId: entry.parentId,
        pendingMentionedUserIds: entry.mentionedUserIds,
      );
      await inject(msg);
    }
  }

  /// Decrypts any failed DM bubble still showing the locked placeholder — the
  /// ones [hydrateOutboxMessages] couldn't read before the vault unlocked.
  /// Call right after unlock, alongside the sidebar refresh.
  Future<void> redecryptFailedMessages() async {
    final userId = state.currentUserId;
    if (userId.isEmpty) return;
    final vault = ref.read(messageVaultProvider);
    if (!vault.isUnlocked) return;
    for (final key in state.feeds.keys.toList()) {
      final feed = state.feeds[key];
      if (feed == null) continue;
      final locked = feed.messages.where(isLockedFailedMessage).toList();
      if (locked.isEmpty) continue;
      final decrypted = await vault.decryptMessages(locked, userId);
      final byId = {for (final m in decrypted) m.id: m};
      setFeed(
        key,
        feed.copyWith(
          messages: feed.messages.map((m) => byId[m.id] ?? m).toList(),
        ),
      );
    }
  }
}

/// True for a failed DM bubble still showing the vault's own placeholder
/// text — i.e. one nothing has actually decrypted yet. Retrying it as-is
/// would resend that placeholder string as the message body, so both
/// [ChatOutboxCache]-driven retry and manual retry must skip these until a
/// real decrypt (in [hydrateOutboxMessages] or [redecryptFailedMessages])
/// replaces the placeholder with real text.
bool isLockedFailedMessage(ChatMessage m) =>
    m.sendStatus == MessageSendStatus.failed && isUnopenedMessage(m);
