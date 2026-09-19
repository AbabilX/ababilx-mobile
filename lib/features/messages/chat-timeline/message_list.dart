import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-date-divider/index.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'call_events_collapse.dart';
import 'message_list_error.dart';
import 'signal_bubble_metrics.dart';
import 'unread_divider.dart';
import 'message_row.dart';
import 'thread_sheet.dart';
import 'group_call_event_row.dart';
import 'timeline_items.dart';
import 'timeline_jump_target.dart';
import 'voice_call_event_row.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (messages.isEmpty && error.isNotEmpty) {
      return MessageListError(message: error, onRetry: onRetry);
    }
    final items = buildChatTimelineItems(messages);
    final idIndex = <String, int>{
      for (var i = 0; i < messages.length; i++) messages[i].id: i,
    };
    final rows = timelineRowKeys(items);
    final hasWallpaper = ref
        .watch(chatWallpaperProvider)
        .forChat(conversationId)
        .isSet;
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      // Rows are built a screen ahead of the scroll, so a photo has decoded
      // before it is on screen rather than fading in as it arrives.
      scrollCacheExtent: const ScrollCacheExtent.viewport(1),
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? rows.positions[key.value] : null,
      // No horizontal padding: a selected row's shade has to reach both
      // screen edges, and the check-circle gutter has to start at the edge
      // too. Every item carries the side inset itself — for a message row it
      // is [SelectableMessageRow], which grows it while selecting.
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      itemCount: items.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (loadingMore && i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final idx = items.length - 1 - i;
        final item = items[idx];
        final prevAnchor = idx > 0 ? items[idx - 1].anchor : null;
        final showDate =
            prevAnchor == null ||
            !isSameDay(prevAnchor.createdAt, item.anchor.createdAt);
        final showUnread =
            unreadAnchorId != null &&
            _itemContainsMessageId(item, unreadAnchorId!);

        return Column(
          key: ValueKey(rows.keys[i]),
          children: [
            if (showDate)
              _inset(
                ChatDateDivider(
                  label: formatDateDivider(item.anchor.createdAt),
                  hasWallpaper: hasWallpaper,
                ),
              ),
            if (showUnread) _inset(UnreadDivider(count: unreadCount)),
            switch (item) {
              ChatTimelineCallEvents(:final messages) => _inset(
                CallEventsCollapse(
                  messages: messages,
                  currentUserId: currentUserId,
                ),
              ),
              ChatTimelineMessage(:final message) => _buildMessage(
                context: context,
                message: message,
                idIndex: idIndex,
              ),
            },
          ],
        );
      },
    );
  }

  Widget _buildMessage({
    required BuildContext context,
    required ChatMessage message,
    required Map<String, int> idIndex,
  }) {
    if (message.isVoiceCall) {
      return _inset(
        VoiceCallEventRow(message: message, currentUserId: currentUserId),
      );
    }
    if (message.isGroupCall) {
      return _inset(GroupCallEventRow(message: message));
    }
    final idx = idIndex[message.id] ?? 0;
    final prev = idx > 0 ? messages[idx - 1] : null;
    final next = idx + 1 < messages.length ? messages[idx + 1] : null;
    final clusterPosition = chatMessageClusterPosition(prev, message, next);
    // Wrapped, not keyed from here: a row is what a tapped quote jumps to, and
    // the wash that lands on it has to reach both screen edges.
    return TimelineJumpTarget(
      messageId: message.id,
      child: MessageRow(
        message: message,
        conversationId: conversationId,
        threadRootId: threadRootId,
        clusterPosition: clusterPosition,
        onOpenThread: threadRootId == null && message.threadCount > 0
            ? () => openThreadSheet(context, conversationId, message)
            : null,
      ),
    );
  }
}

/// The side inset the ListView used to carry. Call events and dividers are
/// never selectable, so they keep it as plain padding.
Widget _inset(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: SignalBubbleMetrics.listSideGutter,
  ),
  child: child,
);

bool _itemContainsMessageId(ChatTimelineItem item, String id) {
  return switch (item) {
    ChatTimelineMessage(:final message) => message.id == id,
    ChatTimelineCallEvents(:final messages) => messages.any((m) => m.id == id),
  };
}
