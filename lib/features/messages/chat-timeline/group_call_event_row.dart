import 'package:flutter/material.dart';

import '../data/models/chat_message.dart';

/// Centered "Group call ended" row in the channel timeline — mirrors web
/// `chat-timeline/group-call-event.tsx`.
class GroupCallEventRow extends StatelessWidget {
  const GroupCallEventRow({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final meta = message.meta ?? const <String, dynamic>{};
    final participants = (meta['participant_count'] as num?)?.toInt() ?? 0;
    final duration = _formatDuration(
      (meta['duration_seconds'] as num?)?.toInt() ?? 0,
    );

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
                  Icons.headset_mic_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Group call ended · $duration · $participants joined',
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
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

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  final tail =
      '${minutes.toString().padLeft(hours > 0 ? 2 : 1, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$tail' : tail;
}
