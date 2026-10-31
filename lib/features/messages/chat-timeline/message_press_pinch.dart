import 'package:flutter/material.dart';

import 'message_menu_metrics.dart';

/// The pinch a bubble takes while a finger rests on it — the reference app's
/// `shrinkBubble`, which eases the bubble to 0.95 during the hold so the
/// lifted copy the menu draws (it starts at that same 0.95) picks up exactly
/// where the bubble left off. Without it the bubble jumped from full size to
/// pinched on the frame the menu opened.
class MessagePressPinch extends StatelessWidget {
  const MessagePressPinch({
    super.key,
    required this.pressed,
    required this.isMine,
    required this.child,
  });

  final ValueNotifier<bool> pressed;
  final bool isMine;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: pressed,
    builder: (context, down, inner) => AnimatedScale(
      scale: down ? MessageMenuMetrics.pressScale : 1.0,
      duration: MessageMenuMetrics.pressDuration,
      // ViewPropertyAnimator's default interpolator.
      curve: Curves.easeInOutSine,
      // The side the bubble hangs on, which is where the lifted copy pins
      // its own pinch.
      alignment: isMine ? Alignment.topRight : Alignment.topLeft,
      child: inner,
    ),
    child: child,
  );
}
