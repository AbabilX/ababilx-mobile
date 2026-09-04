import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-date-divider/index.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'message_list_error.dart';
import 'signal_bubble_metrics.dart';
import 'chat_timeline_unread.dart';
import 'unread_divider.dart';
import 'message_row.dart';
import 'thread_sheet.dart';
import 'group_call_event_row.dart';
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
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        SignalBubbleMetrics.listSideGutter,
        8,
        SignalBubbleMetrics.listSideGutter,
        12,
      ),
      itemCount: messages.length + (loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (loadingMore && i == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final idx = messages.length - 1 - i;
        final msg = messages[idx];
        final prev = idx > 0 ? messages[idx - 1] : null;
        final next = idx + 1 < messages.length ? messages[idx + 1] : null;
        final showDate =
            prev == null || !isSameDay(prev.createdAt, msg.createdAt);
        final clusterPosition = chatMessageClusterPosition(prev, msg, next);
        final hasWallpaper = ref
            .watch(chatWallpaperProvider)
            .forChat(conversationId)
            .isSet;
        return Column(
          children: [
            if (showDate)
              ChatDateDivider(
                label: formatDateDivider(msg.createdAt),
                hasWallpaper: hasWallpaper,
              ),
            if (unreadAnchorId != null && msg.id == unreadAnchorId)
              UnreadDivider(count: unreadCount),
            if (msg.isVoiceCall)
              VoiceCallEventRow(message: msg, currentUserId: currentUserId)
            else if (msg.isGroupCall)
              GroupCallEventRow(message: msg)
            else
              MessageRow(
                message: msg,
                conversationId: conversationId,
                threadRootId: threadRootId,
                clusterPosition: clusterPosition,
                onOpenThread: threadRootId == null && msg.threadCount > 0
                    ? () => openThreadSheet(context, conversationId, msg)
                    : null,
              ),
          ],
        );
      },
    );
  }
}
