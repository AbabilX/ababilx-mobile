part of 'chat_provider.dart';

/// Answering a Signal-style message request from inside the thread.
///
/// Replying accepts on its own — the server does that when the message lands
/// — so everything here is for the person who wants to settle the bar without
/// saying anything yet.
mixin _ChatRequestsMixin on Notifier<ChatState>, _ChatActionsMixin {
  /// Answers an incoming message request. Applied locally first so the bar
  /// gives way to the composer immediately; the sidebar refresh behind it is
  /// what makes the change stick if this device is not the only one open.
  Future<void> acceptMessageRequest(String conversationId) async {
    state = state.copyWith(
      dms: state.dms
          .map(
            (c) =>
                c.id == conversationId ? c.copyWith(requestState: 'none') : c,
          )
          .toList(),
    );
    try {
      await repo.acceptMessageRequest(conversationId);
    } finally {
      await (this as ChatNotifier).fetchSidebar(silent: true);
    }
  }

  /// Block from inside a thread — the durable answer to a message request.
  /// The DM leaves this device's list the way "delete for me" does, but the
  /// block itself is what stops the peer writing again.
  Future<void> blockPeer(String conversationId, String peerUserId) async {
    state = state.copyWith(
      dms: state.dms.where((c) => c.id != conversationId).toList(),
    );
    try {
      await repo.blockUser(peerUserId);
    } finally {
      await (this as ChatNotifier).fetchSidebar(silent: true);
    }
  }
}
