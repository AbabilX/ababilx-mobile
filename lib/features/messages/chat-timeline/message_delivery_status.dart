import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

class MessageDeliveryStatus extends StatelessWidget {
  const MessageDeliveryStatus({
    super.key,
    required this.status,
    required this.pulse,
  });

  final MessageSendStatus status;
  final Animation<double> pulse;

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
      MessageSendStatus.sent => const SizedBox.shrink(),
    };
  }
}
