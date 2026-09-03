import 'package:flutter/material.dart';

import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import 'message_bubble.dart';
import 'message_delivery_status.dart';
import 'signal_bubble_metrics.dart';

/// Time and delivery state, inside the bubble on its last line — where Signal
/// puts them, rather than on a row of their own below the message.
class MessageBubbleFooter extends StatelessWidget {
  const MessageBubbleFooter({
    super.key,
    required this.message,
    required this.colors,
    required this.isOwn,
    required this.isSending,
    required this.isFailed,
    required this.pulse,
  });

  final ChatMessage message;
  final SignalBubbleColors colors;
  final bool isOwn;
  final bool isSending;
  final bool isFailed;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final label = isFailed
        ? 'Tap to retry'
        : isSending
        ? 'Sending…'
        : formatChatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: SignalBubbleMetrics.footerTextSize,
              height: 1.1,
              color: isFailed ? error : colors.muted,
              fontWeight: isFailed ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (isOwn && !isFailed) ...[
            const SizedBox(width: 4),
            MessageDeliveryStatus(
              status: message.sendStatus,
              pulse: pulse,
              delivery: message.delivery,
              color: colors.muted,
            ),
          ],
        ],
      ),
    );
  }
}
