part of 'chat_provider.dart';

/// In-memory edits to an already-loaded feed: a realtime event or a local
/// mutation lands here. Split from [_ChatFeedMixin], which owns loading a feed
/// from the network or from disk.
mixin _ChatFeedEditMixin on Notifier<ChatState>, _ChatFeedMixin {
  void appendFeedMessage(
    String conversationId,
    ChatMessage msg, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final existing = state.feeds[key];
    if (existing == null) {
      // Nobody has opened this feed yet. Keep the decrypted copy so the open
      // shows it on its first frame — see [ReceivedMessageBuffer].
      receivedBuffer.add(key, msg);
      return;
    }
    setFeed(
      key,
      existing.copyWith(
        messages: canonicalChatMessages([...existing.messages, msg]),
        fetchedAt: existing.fetchedAt == 0
            ? 0
            : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void updateFeedMessage(
    String conversationId,
    ChatMessage msg, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) {
      receivedBuffer.patch(msg.id, (_) => msg);
      return;
    }
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.map((m) => m.id == msg.id ? msg : m).toList(),
        fetchedAt: _touched(feed),
      ),
    );
  }

  void removeFeedMessage(
    String conversationId,
    String messageId, {
    String? threadRootId,
  }) {
    receivedBuffer.remove(messageId);
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.where((m) => m.id != messageId).toList(),
      ),
    );
  }

  void updateFeedReactions(
    String conversationId,
    String messageId,
    List<ChatReactionGroup> reactions, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) {
      receivedBuffer.patch(messageId, (m) => m.copyWith(reactions: reactions));
      return;
    }
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages
            .map(
              (m) => m.id == messageId ? m.copyWith(reactions: reactions) : m,
            )
            .toList(),
        fetchedAt: _touched(feed),
      ),
    );
  }

  /// A live edit to a feed painted from disk must not mark it fresh: 0 is
  /// what tells [loadFeed] the server has not been asked yet.
  int _touched(ChatFeed feed) =>
      feed.fetchedAt == 0 ? 0 : DateTime.now().millisecondsSinceEpoch;
}
