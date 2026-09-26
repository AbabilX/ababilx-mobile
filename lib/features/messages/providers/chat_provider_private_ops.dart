part of 'chat_provider.dart';

/// This phone's own edits, reactions and deletes on private-chat messages
/// (server 0160). The target may be gone from the server, so each one is
/// sent as an op — delivered through the same custody queue as a message —
/// and applied to the local copy straight from the op the server stored.
mixin _ChatPrivateOpsMixin on Notifier<ChatState>, _ChatPrivateMixin {
  Future<void> reactPrivately(ChatMessage target, String emoji) async {
    final me = state.currentUserId;
    final reacted = !target.reactions.any(
      (g) =>
          g.emoji == emoji &&
          (g.reactedByMe || g.users.any((u) => u.userId == me)),
    );
    await _sendPrivateOp(target, {
      'kind': PrivateOp.reaction,
      'emoji': emoji,
      'reacted': reacted,
    });
  }

  /// Sealed exactly like a message body; a stale key refuses rather than
  /// re-keying, the same rule an ordinary edit follows.
  Future<void> editPrivately(ChatMessage target, String body) async {
    final sealed = await ref
        .read(messageVaultProvider)
        .encryptExisting(
          conversationId: target.conversationId,
          text: body,
          currentUserId: state.currentUserId,
        );
    await _sendPrivateOp(target, {
      'kind': PrivateOp.edit,
      'encrypted_body': sealed.encryptedBody,
      'encryption_nonce': sealed.nonce,
      'encryption_key_version': sealed.keyVersion,
    });
  }

  Future<void> deletePrivately(ChatMessage target) =>
      _sendPrivateOp(target, {'kind': PrivateOp.delete});

  Future<void> _sendPrivateOp(
    ChatMessage target,
    Map<String, dynamic> body,
  ) async {
    final op = await ref
        .read(privateChatApiProvider)
        .postOp(target.conversationId, {
          ...body,
          'client_op_id': newChatClientMessageId(),
          'target_message_id': target.id,
        });
    await applyPrivateOp(op);
  }
}
