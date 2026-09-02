import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

class MessageDeliveryStatus extends StatelessWidget {
  const MessageDeliveryStatus({
    super.key,
    required this.status,
    required this.pulse,
    this.delivery,
  });

  final MessageSendStatus status;
  final Animation<double> pulse;
  final ChatDeliverySummary? delivery;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (status) {
      MessageSendStatus.sending => FadeTransition(
        opacity: pulse,
        child: Icon(
          Icons.schedule_rounded,
          size: 13,
          color: colors.onSurfaceVariant,
        ),
      ),
      MessageSendStatus.failed => Icon(
        Icons.error_outline_rounded,
        size: 14,
        color: colors.error,
      ),
      MessageSendStatus.sent => Icon(
        (delivery?.deliveredDevices ?? 0) > 0 ||
                (delivery?.readDevices ?? 0) > 0
            ? Icons.done_all_rounded
            : Icons.done_rounded,
        size: 14,
        color: (delivery?.readDevices ?? 0) > 0
            ? colors.primary
            : colors.onSurfaceVariant,
      ),
    };
  }
}
