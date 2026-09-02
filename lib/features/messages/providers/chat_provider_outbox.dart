part of 'chat_provider.dart';

/// Durable send outbox: an outbound message is on disk before the request is
/// even attempted, so a kill mid-send never loses it. Separate from
/// [_ChatCacheMixin] because it owns writes the user made, not a copy of
/// server state that can always be refetched.
mixin _ChatOutboxMixin on Notifier<ChatState>, _ChatFeedMixin {
  ChatOutboxCache get outboxCache;

  // ─── Outbox (durable — see PendingOutboxMessages) ──────────────────────────

  /// Writes [pendingMsg] to the outbox before the network call is even made,
  /// so a send survives an app kill regardless of whether it ever gets to
  /// try. Pass [encrypted] for a DM send — its ciphertext is stored instead
  /// of [pendingMsg.body], never the plaintext. This future must complete
  /// before the caller starts the network request.
  Future<void> persistOutbox(
    String conversationId,
    ChatMessage pendingMsg, {
    EncryptedDmPayload? encrypted,
  }) => outboxCache.save(
    clientRef: pendingMsg.clientRef ?? pendingMsg.id,
    conversationId: conversationId,
    body: encrypted == null ? pendingMsg.body : '',
    parentId: pendingMsg.pendingParentId,
    attachments: pendingMsg.pendingAttachments,
    mentionedUserIds: pendingMsg.pendingMentionedUserIds,
    encryptedBody: encrypted?.encryptedBody,
    encryptionNonce: encrypted?.nonce,
    encryptionKeyVersion: encrypted?.keyVersion,
  );

  void removeFromOutboxAsync(String clientRef) {
    outboxCache.remove(clientRef).ignore();
  }

  /// Reloads every outstanding send left over from a previous session and
  /// re-injects it as a failed bubble in its conversation's feed, so it
  /// shows up as "tap to retry" immediately — and so [retryPendingMessages]
  /// (fired on the next WS reconnect) picks it up without the user having to
  /// open that conversation first. A DM entry only decrypts here if the
  /// vault is already unlocked; otherwise it shows the same "Encrypted
  /// message" placeholder used everywhere else until [redecryptFailedMessages]
  /// runs after unlock.
  Future<void> hydrateOutboxMessages() async {
    final userId = state.currentUserId;
    if (userId.isEmpty) return;
    final entries = await outboxCache.readAll();
    final vault = ref.read(messageVaultProvider);
    for (final entry in entries) {
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
      if (entry.isEncrypted && vault.isUnlocked) {
        msg = await vault.decryptMessage(msg, userId);
      }
      final key = feedKey(entry.conversationId, threadRootId: entry.parentId);
      final feed =
          state.feeds[key] ??
          ChatFeed(fetchedAt: DateTime.now().millisecondsSinceEpoch);
      if (feed.messages.any((m) => m.id == msg.id)) continue;
      setFeed(key, feed.copyWith(messages: [...feed.messages, msg]));
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
    m.sendStatus == MessageSendStatus.failed &&
    m.isEncrypted &&
    (m.body.isEmpty ||
        m.body == 'Encrypted message' ||
        m.body == 'Unable to decrypt this message');
