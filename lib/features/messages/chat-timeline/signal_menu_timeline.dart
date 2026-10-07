import 'package:flutter/animation.dart';

import 'signal_menu_metrics.dart';

/// One piece of Signal's reveal, cut out of the route's single animation.
///
/// Signal runs every piece on its own 200ms tween with its own start delay
/// (`ChatReactionOverlay`): the message at 0, the strip at 100, each emoji 10
/// after the last. Squeezing all of that into one 200ms run — which this
/// overlay did — plays the stagger at more than double speed and reads as a
/// pop. The route now lasts the whole sequence and each piece takes its slice.
///
/// The hide is not the reveal backwards: every piece leaves together over
/// 150ms on a decelerate, which `reverseCurve` supplies (the route's value
/// runs 1→0, so the flipped curve is the decelerate of the way out).
CurvedAnimation signalReveal(
  Animation<double> route, {
  Duration delay = Duration.zero,
  Curve curve = Curves.decelerate,
}) {
  final total = SignalMenuMetrics.revealTotal.inMilliseconds;
  final start = delay.inMilliseconds / total;
  final end = (delay + SignalMenuMetrics.revealDuration).inMilliseconds / total;
  return CurvedAnimation(
    parent: route,
    curve: Interval(start, end.clamp(0.0, 1.0), curve: curve),
    reverseCurve: Curves.decelerate.flipped,
  );
}

/// The emoji in slot [index]: after the strip's offset, 10ms behind the one
/// before it.
CurvedAnimation signalEmojiReveal(Animation<double> route, int index) =>
    signalReveal(
      route,
      delay:
          SignalMenuMetrics.revealOffset +
          SignalMenuMetrics.emojiStagger * index,
    );
