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
    // Only update an already-loaded feed. If the feed has never been fetched,
    // skip — it will be loaded fresh (with full history) when the user opens
    // the conversation. Appending to an empty/unfetched feed would prevent the
    // full-history load from replacing it and leave the feed with only 1 msg.
    if (existing == null || existing.fetchedAt == 0) return;
    if (existing.messages.any((m) => m.id == msg.id)) return;
    setFeed(
      key,
      existing.copyWith(
        messages: [...existing.messages, msg],
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
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
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.map((m) => m.id == msg.id ? msg : m).toList(),
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void removeFeedMessage(
    String conversationId,
    String messageId, {
    String? threadRootId,
  }) {
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
    if (feed == null) return;
    setFeed(
      key,
      feed.copyWith(
        messages: feed.messages
            .map(
              (m) => m.id == messageId ? m.copyWith(reactions: reactions) : m,
            )
            .toList(),
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
