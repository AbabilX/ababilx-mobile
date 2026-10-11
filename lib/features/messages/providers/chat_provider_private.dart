part of 'chat_provider.dart';

/// Private chat (server 0160), this phone's half of the custody deal: the
/// server keeps a private message only until every phone of both people says
/// it holds it — the author's too, or a message written in a browser or on
/// the other phone would reach no phone of its author — so this phone must
/// take each one — written to disk, media downloaded — and then say so. It also pulls the ones it was never shown
/// (chat not opened, socket down) and applies ops to its own copies.
///
/// The order is the whole point and must not be reordered:
///
///     written to disk  ->  media downloaded  ->  POST custody
///
/// A crash before the POST leaves the server's copy for the next pull. The
/// delivered tick is NOT custody: it goes out on receipt, before anything is
/// written, and purging on it would lose a message to a crash.
mixin _ChatPrivateMixin
    on
        Notifier<ChatState>,
        _ChatPatchMixin,
        _ChatFeedMixin,
        _ChatFeedEditMixin,
        _ChatCacheMixin {
  Future<void>? _privatePull;
  final Set<String> _custodyInFlight = {};

  /// Confirms custody of every private message in [messages], this
  /// account's own included, once each is on disk with its media. Anything
  /// else is skipped, so any page or event can be handed over as it is, and
  /// twice is harmless.
  Future<void> takePrivateCustody(List<ChatMessage> messages) async {
    final owed = [
      for (final m in messages)
        if (m.privateChat &&
            !m.isPending &&
            m.id.isNotEmpty &&
            _custodyInFlight.add(m.id))
          m,
    ];
    if (owed.isEmpty) return;
    try {
      // Must throw on a failed write: custody is what lets the server delete
      // its copy, and saveAll swallows every disk error.
      await messageStore.saveDurable(owed);
      final taken = await takePrivateMedia(ref, owed);
      if (taken.isEmpty) return;
      final device = await (this as ChatNotifier).repo.chatDeviceId();
      await ref.read(privateChatApiProvider).custody(device, taken.toList());
    } catch (e) {
      // Still on the server: the next pull offers them again.
      debugPrint('[PrivateChat] custody not taken: $e');
    } finally {
      _custodyInFlight.removeAll(owed.map((m) => m.id));
    }
  }

  /// Takes whatever private messages and ops the server still holds for this
  /// phone. Runs at launch, on every socket reconnect and on return to the
  /// foreground; one at a time.
  Future<void> pullPrivatePending() =>
      _privatePull ??= _pullPrivate().whenComplete(() {
        _privatePull = null;
      });

  Future<void> _pullPrivate() async {
    final String device;
    try {
      device = await (this as ChatNotifier).repo.chatDeviceId();
    } catch (_) {
      return;
    }
    final api = ref.read(privateChatApiProvider);
    // Bounded: items this phone cannot take yet (an unopened timed photo)
    // come back on every page and must not spin the loop.
    for (var round = 0; round < 10 && !isDisposed; round++) {
      final PrivatePending page;
      try {
        page = await api.pending(device);
      } catch (_) {
        return;
      }
      if (page.isEmpty || isDisposed) return;
      final opened = canonicalChatMessages(
        await decryptIfNeeded(page.messages),
      );
      await messageStore.saveAll(opened);
      for (final message in opened) {
        _showPulled(message);
      }
      await takePrivateCustody(opened);
      for (final op in page.ops) {
        await applyPrivateOp(op);
      }
      if (!page.hasMore) return;
    }
  }

  /// A pulled message joins its feed (or the buffer an unopened feed reads
  /// first) and, when it is the newest, the list preview. Unread is not
  /// touched: the server already counted it (`private_unread`).
  void _showPulled(ChatMessage message) {
    final conv = state.conversationById(message.conversationId);
    appendFeedMessage(message.conversationId, message);
    final shown = DateTime.tryParse(conv?.lastMessageAt ?? '');
    final at = DateTime.tryParse(message.createdAt);
    if (conv == null || shown == null || (at != null && !at.isBefore(shown))) {
      applyIncomingMessage(message.conversationId, message, bumpUnread: false);
    }
  }

  /// Applies one op to this phone's copy of its target, then confirms custody
  /// of the op (this account's own too: it may have been made on the other
  /// phone or in a browser). A target not here yet (still on a later page)
  /// leaves an edit or reaction pending for the next pull. A delete with no
  /// target is taken: the server removes a message it still holds when the
  /// delete arrives, so that message can never come later — and this
  /// phone's own delete has already forgotten its target.
  Future<void> applyPrivateOp(PrivateOp op) async {
    final me = state.currentUserId;
    final target =
        _loadedMessage(op.conversationId, op.targetMessageId) ??
        await messageStore.byId(op.targetMessageId);
    if (target == null && op.kind != PrivateOp.delete) return;
    if (target == null) {
      await messageStore.deletions.rememberMessage(
        op.conversationId,
        op.targetMessageId,
      );
    } else {
      try {
        await _applyToTarget(op, target, me);
      } catch (e) {
        // Not applied on disk: the op stays on the server for the next pull.
        debugPrint('[PrivateChat] op not applied: $e');
        return;
      }
    }
    try {
      final device = await (this as ChatNotifier).repo.chatDeviceId();
      await ref.read(privateChatApiProvider).custody(device, [op.id]);
    } catch (_) {}
  }

  Future<void> _applyToTarget(
    PrivateOp op,
    ChatMessage target,
    String me,
  ) async {
    switch (privateOpEffect(op, target)) {
      case PrivateOpEffect.ignore:
        break;
      case PrivateOpEffect.react:
        final reactions = applyPrivateReaction(
          target.reactions,
          userId: op.senderId,
          currentUserId: me,
          emoji: op.emoji,
          reacted: op.reacted,
          userName: _privateOpAuthorName(op),
        );
        await messageStore.saveDurable([target.copyWith(reactions: reactions)]);
        updateFeedReactions(op.conversationId, target.id, reactions);
      case PrivateOpEffect.edit:
        final edited = target.copyWith(
          editedAt: op.createdAt,
          encryptedBody: op.encryptedBody,
          encryptionNonce: op.encryptionNonce,
          encryptionVersion: 1,
          encryptionKeyVersion: op.encryptionKeyVersion,
        );
        await messageStore.saveDurable([edited]);
        final opened = (await decryptIfNeeded([edited])).first;
        updateFeedMessage(op.conversationId, opened);
      case PrivateOpEffect.delete:
        await _forgetPrivateMessage(op.conversationId, target.id);
    }
  }

  ChatMessage? _loadedMessage(String conversationId, String messageId) {
    for (final m in state.feedFor(conversationId).messages) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  String? _privateOpAuthorName(PrivateOp op) {
    final conv = state.conversationById(op.conversationId);
    return conv?.peerUserId == op.senderId ? conv?.peerUserName : null;
  }

  /// Delete for everyone, applied here: the same forgetting a server delete
  /// gets, for a message the server may never have held when it happened.
  Future<void> _forgetPrivateMessage(
    String conversationId,
    String messageId,
  ) async {
    await messageStore.deletions.rememberMessage(conversationId, messageId);
    await ref.read(attachmentSweeperProvider).onMessageDeleted(messageId);
    await messageStore.remove(messageId);
    removeFeedMessage(conversationId, messageId);
  }
}
