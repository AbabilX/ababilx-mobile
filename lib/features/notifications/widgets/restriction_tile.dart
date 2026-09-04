import 'package:flutter/material.dart';

/// One background-restriction row on the notification settings screen.
///
/// Shared by the battery-optimization and Data Saver tiles: same shape, same
/// "solved" state, different question. [onTap] is null once there is nothing
/// left to fix.
class RestrictionTile extends StatelessWidget {
  const RestrictionTile({
    super.key,
    required this.title,
    required this.body,
    required this.solved,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String body;
  final bool solved;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: solved ? colors.primary : colors.error,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  solved
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: solved ? colors.primary : colors.onSurfaceVariant,
                  size: solved ? 20 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
