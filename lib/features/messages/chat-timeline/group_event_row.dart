import 'package:flutter/material.dart';

import '../data/models/chat_message.dart';
import 'group_event_label.dart';

/// Quiet centered system line for group updates — name/photo/member/role
/// changes and the like. Not a chat bubble; mirrors WhatsApp/Signal and web
/// `GroupEventRow`.
class GroupEventRow extends StatelessWidget {
  const GroupEventRow({
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
    final label = groupEventLabel(message, currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
