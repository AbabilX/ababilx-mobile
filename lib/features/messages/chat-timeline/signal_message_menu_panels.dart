import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'signal_message_menu.dart';
import 'signal_message_menu_geometry.dart';

/// The scrubber: 320 wide, one action-bar tall, 30dp corner, seven equal slots
/// — six emoji and the "more" circle. The strip fades in, then each emoji
/// rises 25dp into place, one after the next, which is the whole character of
/// Signal's reveal.
class SignalReactionBar extends StatelessWidget {
  const SignalReactionBar({
    super.key,
    required this.moreLabel,
    required this.strip,
    required this.slots,
    this.selectedIndex,
  });

  final String moreLabel;

  /// The strip's own fade, and one reveal per slot (`signalEmojiReveal`).
  final Animation<double> strip;
  final List<Animation<double>> slots;

  /// Slot the finger is scrubbing over, if any — it grows and lifts.
  final int? selectedIndex;

  /// Signal's default six, in Signal's order.
  static const emojis = ['❤️', '👍', '👎', '😂', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The emoji sit over the strip, not inside its fade: each has its own.
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: strip,
          child: Material(
            color: colors.surfaceContainerHigh,
            elevation: 4,
            borderRadius: BorderRadius.circular(SignalMenuMetrics.barRadius),
          ),
        ),
        _slots(context, colors),
      ],
    );
  }

  Widget _slots(BuildContext context, ColorScheme colors) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: SignalMenuMetrics.barHeight,
        child: Row(
          children: [
            for (var i = 0; i < emojis.length; i++)
              Expanded(
                child: _Slot(
                  animation: slots[i],
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
                animation: slots[emojis.length],
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
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final Animation<double> animation;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curve = animation;
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
