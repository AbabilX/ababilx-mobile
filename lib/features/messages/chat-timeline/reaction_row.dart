import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

/// Signal's reaction pill: one capsule hanging off the bottom edge of the
/// bubble, overlapping it. The parent column aligns it to the bubble's own
/// side, so this only owns the overlap.
///
/// There is no "add" button on the pill — reacting starts from the emoji bar
/// on the long-press overlay ([SignalReactionBar]), same as Signal. Tapping an
/// emoji here toggles your own.
class ReactionRow extends StatelessWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    required this.onToggle,
    this.hasWallpaper = false,
  });

  final List<ChatReactionGroup> reactions;
  final ValueChanged<String> onToggle;
  final bool hasWallpaper;

  /// How far the pill rides up over the bubble's bottom edge.
  static const overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final reactedByMe = reactions.any((r) => r.reactedByMe);
    final total = reactions.fold<int>(0, (sum, r) => sum + r.count);

    return Transform.translate(
      offset: const Offset(0, -overlap),
      child: Material(
        color: hasWallpaper
            ? colors.surfaceContainerHighest
            : colors.surfaceContainerHigh,
        shape: StadiumBorder(
          side: BorderSide(
            color: reactedByMe
                ? colors.primary.withValues(alpha: 0.55)
                : colors.outlineVariant.withValues(alpha: 0.4),
            width: reactedByMe ? 1.4 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in reactions) ...[
                InkWell(
                  onTap: () => onToggle(r.emoji),
                  customBorder: const StadiumBorder(),
                  child: Text(
                    r.emoji,
                    style: const TextStyle(fontSize: 14, height: 1.1),
                  ),
                ),
                const SizedBox(width: 3),
              ],
              // Signal shows a single total beside the emoji, not a count
              // per emoji — the breakdown lives in the details sheet.
              if (total > 1)
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
