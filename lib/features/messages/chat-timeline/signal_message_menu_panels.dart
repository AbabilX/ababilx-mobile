import 'package:flutter/material.dart';

import 'signal_message_menu.dart';
import 'signal_message_menu_geometry.dart';
import 'signal_message_menu_items.dart';

/// The scrubber: 320 wide, one action-bar tall, 30dp corner, seven equal slots
/// — six emoji and the "more" circle. Each emoji rises 25dp into place, one
/// after the next, which is the whole character of Signal's reveal.
class SignalReactionBar extends StatelessWidget {
  const SignalReactionBar({
    super.key,
    required this.moreLabel,
    required this.animation,
  });

  final String moreLabel;
  final Animation<double> animation;

  /// Signal's default six, in Signal's order.
  static const emojis = ['❤️', '👍', '👎', '😂', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 4,
      borderRadius: BorderRadius.circular(SignalMenuMetrics.barRadius),
      child: SizedBox(
        height: SignalMenuMetrics.barHeight,
        child: Row(
          children: [
            for (var i = 0; i < emojis.length; i++)
              Expanded(
                child: _Slot(
                  animation: animation,
                  index: i,
                  onTap: () => Navigator.pop(
                    context,
                    SignalMessageReaction(emojis[i]),
                  ),
                  child: Text(
                    emojis[i],
                    style: const TextStyle(fontSize: 30),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            Expanded(
              child: _Slot(
                animation: animation,
                index: emojis.length,
                onTap: () => Navigator.pop(
                  context,
                  const SignalMessageReaction(''),
                ),
                child: Tooltip(
                  message: moreLabel,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: colors.surfaceContainerHighest,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.animation,
    required this.index,
    required this.onTap,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Signal staggers by duration / 10 per slot; as a fraction of one reveal
    // that is the same tenth per emoji.
    final start = (index * 0.1).clamp(0.0, 0.6);
    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0)),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, inner) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(
            0,
            SignalMenuMetrics.emojiRiseFrom * (1 - curve.value),
          ),
          child: inner,
        ),
      ),
      child: InkResponse(radius: 26, onTap: onTap, child: Center(child: child)),
    );
  }
}

/// The context menu: 18dp corner, rows of a 24dp icon and BodyLarge with 16dp
/// side padding and 13dp above and below.
class SignalActionPanel extends StatelessWidget {
  const SignalActionPanel({super.key, required this.items});

  final List<SignalMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 20,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(SignalMenuMetrics.menuRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final item in items) _ActionRow(item: item)],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});

  final SignalMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destructive = item.action == SignalMessageAction.delete;
    final color = destructive ? colors.error : colors.onSurface;
    return InkWell(
      onTap: () => Navigator.pop(context, SignalMessageCommand(item.action)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SignalMenuMetrics.menuRowPadding,
          vertical: 13,
        ),
        child: Row(
          children: [
            Icon(item.icon, size: SignalMenuMetrics.menuIconSize, color: color),
            const SizedBox(width: SignalMenuMetrics.menuIconGap),
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
