import 'package:flutter/material.dart';

import '../providers/user_status_provider.dart';

/// Slack-style custom status chip — emoji + short text, theme tokens only.
class UserStatusBadge extends StatelessWidget {
  const UserStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.borderRadius,
    this.maxWidth,
  });

  final UserStatus status;

  /// Smaller text for list rows / dense tiles.
  final bool compact;

  /// Defaults to a fully-rounded pill; pass a fixed value (e.g. to match
  /// [AppAvatar.radius]) when placed right next to an avatar.
  final double? borderRadius;

  /// Caps the chip width (with ellipsis) — used where space is tight, e.g.
  /// beside the profile avatar where it must not crowd the workspace name.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final content = Container(
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(borderRadius ?? 999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.emoji.isNotEmpty) ...[
            Text(status.emoji, style: TextStyle(fontSize: compact ? 11 : 13)),
            SizedBox(width: compact ? 3 : 4),
          ],
          Flexible(
            child: Text(
              status.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact ? textTheme.labelSmall : textTheme.labelMedium)
                  ?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
            ),
          ),
        ],
      ),
    );
    return content;
  }
}
