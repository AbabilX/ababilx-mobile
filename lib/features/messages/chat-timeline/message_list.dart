import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-date-divider/date_jump.dart';
import '../chat-date-divider/index.dart';
import '../chat-typing/typing_bubble.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'call_events_collapse.dart';
import 'bubble_side_indicators.dart';
import 'message_list_error.dart';
import 'quote_chain.dart';
import 'unread_divider.dart';
import 'group_events_collapse.dart';
import 'timeline_items.dart';
import 'timeline_message_item.dart';

class MessageList extends ConsumerWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.loading,
    required this.loadingMore,
    required this.currentUserId,
    required this.scrollController,
    required this.conversationId,
    this.threadRootId,
    this.error = '',
    this.onRetry,
    this.unreadAnchorId,
    this.unreadCount = 0,
    this.leading,
    this.insetTop = 0,
    this.insetBottom = 0,
    this.indicators = true,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingMore;
  final String currentUserId;
  final ScrollController scrollController;
  final String conversationId;
  final String? threadRootId;
  final String error;
  final VoidCallback? onRetry;

  /// Message the "N unread messages" bar sits above, pinned once by
  /// [ChatTimelineUnread] so later arrivals cannot shift it, and null when
  /// there is no bar to draw.
  final String? unreadAnchorId;

  /// The number that bar reports.
  final int unreadCount;

  /// Drawn above the oldest message and scrolled with the list — a thread's
  /// root. It stays up while the replies load or fail, so those two states
  /// become rows under it instead of replacing the whole list.
  final Widget? leading;

  /// Room kept clear at each end for bars floating over the list (the
  /// selection capsules), so the first and last rows are never under them.
  final double insetTop;
  final double insetBottom;

  /// Side marks for a quoted message and a thread root. Off in the replies
  /// sheet, which is where the quoted mark leads.
  final bool indicators;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstLoad = loading && messages.isEmpty;
    final failed = messages.isEmpty && error.isNotEmpty;
    if (leading == null && firstLoad) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (leading == null && failed) {
      return MessageListError(message: error, onRetry: onRetry);
    }
    // Past the messages, oldest end first: the spinner, then [leading].
    final spinner = loadingMore || firstLoad;
    final tail = [
      if (spinner)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (failed)
        MessageListError(message: error, onRetry: onRetry),
      ?leading,
    ];
    final items = buildChatTimelineItems(messages);
    final idIndex = <String, int>{
      for (var i = 0; i < messages.length; i++) messages[i].id: i,
    };
    final rows = timelineRowKeys(items);
    // DMs and groups: index 0 (newest end of a reverse list) is the typing
    // bubble. The header's "typing…" stays beside it.
    final typingSlot = typingBubbleSlot(ref, conversationId) ? 1 : 0;
    final hasWallpaper = ref
        .watch(chatWallpaperProvider)
        .forChat(conversationId)
        .isSet;
    final list = ListView.builder(
      controller: scrollController,
      reverse: true,
      // Rows are built a screen ahead of the scroll, so a photo has decoded
      // before it is on screen rather than fading in as it arrives.
      scrollCacheExtent: const ScrollCacheExtent.viewport(1),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final pos = rows.positions[key.value];
        if (pos == null) return null;
        return pos + typingSlot;
      },
      // No horizontal padding: a selected row's shade has to reach both
      // screen edges, and the check-circle gutter has to start at the edge
      // too. Every item carries the side inset itself — for a message row it
      // is [SelectableMessageRow], which grows it while selecting.
      padding: EdgeInsets.fromLTRB(0, 8 + insetTop, 0, 12 + insetBottom),
      itemCount: items.length + tail.length + typingSlot,
      itemBuilder: (context, i) {
        if (typingSlot == 1 && i == 0) {
          return ChatTypingBubble(
            conversationId: conversationId,
            messages: messages,
          );
        }
        final listIndex = i - typingSlot;
        if (listIndex >= items.length) {
          return tail[listIndex - items.length];
        }
        final idx = items.length - 1 - listIndex;
        final item = items[idx];
        final prevAnchor = idx > 0 ? items[idx - 1].anchor : null;
        final showDate =
            prevAnchor == null ||
            !isSameDay(prevAnchor.createdAt, item.anchor.createdAt);
        final showUnread =
            unreadAnchorId != null &&
            timelineItemContains(item, unreadAnchorId!);

        return Column(
          key: ValueKey(rows.keys[listIndex]),
          children: [
            if (showDate)
              timelineInset(
                ChatDateDivider(
                  label: formatDateDivider(item.anchor.createdAt),
                  hasWallpaper: hasWallpaper,
                  onTap: () => showDateJumpSheet(
                    context,
                    ref,
                    conversationId: conversationId,
                    threadRootId: threadRootId,
                  ),
                ),
              ),
            if (showUnread) timelineInset(UnreadDivider(count: unreadCount)),
            switch (item) {
              ChatTimelineCallEvents(:final messages) => timelineInset(
                CallEventsCollapse(
                  messages: messages,
                  currentUserId: currentUserId,
                ),
              ),
              ChatTimelineGroupEvents(:final messages) => timelineInset(
                GroupEventsCollapse(
                  messages: messages,
                  currentUserId: currentUserId,
                ),
              ),
              ChatTimelineMessage(:final message) => TimelineMessageItem(
                message: message,
                messages: messages,
                index: idIndex[message.id] ?? 0,
                currentUserId: currentUserId,
                conversationId: conversationId,
                threadRootId: threadRootId,
              ),
            },
          ],
        );
      },
    );
    if (!indicators) return list;
    return BubbleIndicatorScope(
      quotedIds: quotedMessageIds(messages),
      threadRootId: threadRootId,
      child: list,
    );
  }
}
