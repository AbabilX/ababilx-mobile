import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'signal_menu_metrics.dart';

/// The long-pressed message, redrawn over the scrim, moving from where it sits
/// in the list ([anchor]) to where the menu needs it ([target]).
class SignalFocusedMessage extends StatelessWidget {
  const SignalFocusedMessage({
    super.key,
    required this.move,
    required this.anchor,
    required this.target,
    required this.targetScale,
    required this.isMine,
    required this.child,
  });

  final Animation<double> move;
  final Rect anchor;
  final Rect target;
  final double targetScale;
  final bool isMine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: move,
      builder: (context, child) {
        final scale = lerpDouble(
          SignalMenuMetrics.pressScale,
          targetScale,
          move.value,
        )!;
        // The message slides from where it sits in the list to where the
        // overlay needs it, unpinching from Signal's 0.95 press scale on
        // the way — exactly how it animates x/y/scale. It pinches in from
        // the side it hangs on, so both ends of the lerp are the painted
        // top-left corner and `Alignment.topLeft` makes the transform
        // land on it exactly.
        final pressLeft = isMine
            ? anchor.right - anchor.width * SignalMenuMetrics.pressScale
            : anchor.left;
        final corner = Offset.lerp(
          Offset(pressLeft, anchor.top),
          target.topLeft,
          move.value,
        )!;
        // The box keeps the message's own size at every frame and only
        // the transform shrinks it. Sizing the box to the scaled rect
        // instead — which `Positioned.fromRect(layout.bubble)` did —
        // hands the message a tight height smaller than it needs, and a
        // long one answers with a render overflow stripe across the
        // bubble. Android has the same split: `setScaleY` is a paint
        // property and leaves the view's layout height alone.
        return Positioned(
          left: corner.dx,
          top: corner.dy,
          width: anchor.width,
          height: anchor.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            // The copy is laid out again here and can come out a few
            // pixels taller than the row it was measured from — a long
            // collapsed body with "Read more", a link preview that
            // resolved in between. A tight height turned that into an
            // overflow stripe; let it take its own height instead.
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: IgnorePointer(child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
