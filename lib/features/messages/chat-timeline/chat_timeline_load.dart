import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_utils.dart';
import '../providers/chat_provider.dart';
import 'chat_timeline.dart';

/// Opening a conversation: what gets fetched, in what order, and the unread
/// count that has to be read before the fetch wipes it.
mixin ChatTimelineLoad on ConsumerState<ChatTimeline> {
  void loadFeed() {
    if (!mounted) return;
    final n = ref.read(chatProvider.notifier);
    ChatOpenTrace.start(
      feedKey(widget.conversationId, threadRootId: widget.threadRootId),
    );
    // Cache-first: the disk page and the network refresh start together
    // inside loadFeed, and the disk never waits for the network. Summaries
    // under thread roots fill from disk as soon as the page is in memory.
    n
        .hydrateFeedFromCache(
          widget.conversationId,
          threadRootId: widget.threadRootId,
        )
        .then((_) {
          if (!mounted || widget.threadRootId != null) return;
          n.prefetchThreadSummaries(widget.conversationId);
        });
    n.loadFeed(
      widget.conversationId,
      threadRootId: widget.threadRootId,
      force: true,
    );
    if (widget.threadRootId == null) {
      n.markConversationRead(widget.conversationId);
    }
  }

  /// Unread count as the chat opens — [loadFeed] marks it read a frame later,
  /// so the divider has to be pinned before that lands. A thread sheet is
  /// opened deliberately and is always read, so it never carries one.
  int currentUnread() {
    if (widget.threadRootId != null) return 0;
    return ref
            .read(chatProvider)
            .conversationById(widget.conversationId)
            ?.unreadCount ??
        0;
  }
}
