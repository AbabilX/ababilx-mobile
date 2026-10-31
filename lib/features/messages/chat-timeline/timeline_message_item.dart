import 'package:flutter/material.dart';

import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import 'group_call_event_row.dart';
import 'group_event_row.dart';
import 'message_row.dart';
import 'bubble_metrics.dart';
import 'thread_sheet.dart';
import 'timeline_jump_target.dart';
import 'voice_call_event_row.dart';

/// One message of the timeline: an event line for the kinds that are not
/// bubbles, a [MessageRow] for the rest.
class TimelineMessageItem extends StatelessWidget {
  const TimelineMessageItem({
    super.key,
    required this.message,
    required this.messages,
    required this.index,
    required this.currentUserId,
    required this.conversationId,
    this.threadRootId,
  });

  final ChatMessage message;
  final List<ChatMessage> messages;
  final int index;
  final String currentUserId;
  final String conversationId;
  final String? threadRootId;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return timelineInset(
        GroupEventRow(message: message, currentUserId: currentUserId),
      );
    }
    if (message.isVoiceCall) {
      return timelineInset(
        VoiceCallEventRow(message: message, currentUserId: currentUserId),
      );
    }
    if (message.isGroupCall) {
      return timelineInset(GroupCallEventRow(message: message));
    }
    final prev = index > 0 ? messages[index - 1] : null;
    final next = index + 1 < messages.length ? messages[index + 1] : null;
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
Widget timelineInset(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: BubbleMetrics.listSideGutter),
  child: child,
);
