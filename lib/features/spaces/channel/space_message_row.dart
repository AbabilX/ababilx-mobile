import 'package:flutter/material.dart';

import '../data/space_message.dart';
import '../data/space_models.dart';

/// Discord-style row: avatar, name + time, body. Pending is faded; failed
/// says so and retries on tap.
class SpaceMessageRow extends StatelessWidget {
  const SpaceMessageRow({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final SpaceMessage message;
  final VoidCallback onRetry;

  static String time(DateTime? t) {
    if (t == null) return '';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final local = message.pending || message.failed;
    final name = message.authorName.isNotEmpty
        ? message.authorName
        : (local ? 'You' : 'AbabilX user');
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: c.surfaceContainerHighest,
            child: Text(
              spaceInitials(name),
              style: theme.textTheme.labelLarge?.copyWith(color: c.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time(message.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(message.body, style: theme.textTheme.bodyMedium),
                if (message.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Not sent · Tap to retry',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: c.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: message.pending ? 0.55 : 1,
      child: message.failed ? InkWell(onTap: onRetry, child: row) : row,
    );
  }
}
