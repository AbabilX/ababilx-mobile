import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'signal_message_menu.dart';
import 'signal_message_menu_geometry.dart';

/// The scrubber: 320 wide, one action-bar tall, 30dp corner, seven equal slots
/// — six emoji and the "more" circle. Each emoji rises 25dp into place, one
/// after the next, which is the whole character of Signal's reveal.
class SignalReactionBar extends StatelessWidget {
  const SignalReactionBar({
    super.key,
    required this.moreLabel,
    required this.animation,
    this.selectedIndex,
  });

  final String moreLabel;
  final Animation<double> animation;

  /// Slot the finger is scrubbing over, if any — it grows and lifts.
  final int? selectedIndex;

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
                  selected: selectedIndex == i,
                  onTap: () =>
                      Navigator.pop(context, SignalMessageReaction(emojis[i])),
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
                selected: selectedIndex == emojis.length,
                onTap: () =>
                    Navigator.pop(context, const SignalMessageReaction('')),
                child: Tooltip(
                  message: moreLabel,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: colors.surfaceContainerHighest,
                    child: ChatIcon(
                      HugeIcons.strokeRoundedMoreHorizontal,
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
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final bool selected;
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
      child: AnimatedSlide(
        duration: SignalMenuMetrics.revealDuration,
        curve: Curves.decelerate,
        // 25 of a 56-tall slot — the lift is expressed against the bar height
        // because AnimatedSlide works in fractions of the child.
        offset: selected
            ? const Offset(
                0,
                -SignalMenuMetrics.emojiLift / SignalMenuMetrics.barHeight,
              )
            : Offset.zero,
        child: AnimatedScale(
          duration: SignalMenuMetrics.revealDuration,
          curve: Curves.decelerate,
          scale: selected ? SignalMenuMetrics.emojiGrowScale : 1.0,
          child: InkResponse(
            radius: 26,
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
