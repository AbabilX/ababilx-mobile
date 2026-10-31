import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

class MessageDeliveryStatus extends StatelessWidget {
  const MessageDeliveryStatus({
    super.key,
    required this.status,
    required this.pulse,
    this.delivery,
    this.color,
    this.seen = false,
  });

  final MessageSendStatus status;
  final Animation<double> pulse;
  final ChatDeliverySummary? delivery;

  /// Inside a bubble the ticks take the bubble's own muted foreground —
  /// `onSurfaceVariant` is invisible on the outgoing accent fill.
  final Color? color;

  /// Seen by read time, for a message whose receipts the server let go.
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = color ?? colors.onSurfaceVariant;
    // Green wins over the bubble's ink: seen has to read at a glance.
    final seenInk = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF22C55E)
        : const Color(0xFF16A34A);
    final isRead = seen || (delivery?.readDevices ?? 0) > 0;
    return switch (status) {
      MessageSendStatus.sending => FadeTransition(
        opacity: pulse,
        child: Icon(Icons.schedule_rounded, size: 13, color: muted),
      ),
      MessageSendStatus.uploading => FadeTransition(
        opacity: pulse,
        child: Icon(Icons.upload_rounded, size: 13, color: muted),
      ),
      MessageSendStatus.failed => Icon(
        Icons.error_outline_rounded,
        size: 14,
        color: colors.error,
      ),
      MessageSendStatus.sent => Icon(
        isRead || (delivery?.deliveredDevices ?? 0) > 0
            ? Icons.done_all_rounded
            : Icons.done_rounded,
        size: 14,
        color: isRead ? seenInk : muted,
      ),
    };
  }
}
