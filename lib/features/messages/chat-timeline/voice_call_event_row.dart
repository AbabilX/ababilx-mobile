import 'package:flutter/material.dart';

import '../data/models/chat_message.dart';
import '../voice_call_message_label.dart';

/// Centered WhatsApp-style voice call history row in the DM timeline.
class VoiceCallEventRow extends StatelessWidget {
  const VoiceCallEventRow({
    super.key,
    required this.message,
    required this.currentUserId,
  });

  final ChatMessage message;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final missed = isMissedStyleVoiceCall(message, currentUserId);
    final iconColor = missed ? colors.error : colors.onSurfaceVariant;
    final label = voiceCallMessageLabel(message, currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  missed ? Icons.phone_missed_rounded : Icons.call_rounded,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
