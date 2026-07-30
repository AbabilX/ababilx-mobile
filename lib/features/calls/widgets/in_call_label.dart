import 'package:flutter/material.dart';

/// Slack-style "In a call" chip — theme tokens only.
class InCallLabel extends StatelessWidget {
  const InCallLabel({
    super.key,
    this.compact = false,
  });

  /// Smaller text for list rows / dense tiles.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_in_talk_rounded,
            size: compact ? 11 : 13,
            color: colors.onTertiaryContainer,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            'In a call',
            style: (compact ? textTheme.labelSmall : textTheme.labelMedium)
                ?.copyWith(
                  color: colors.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}
