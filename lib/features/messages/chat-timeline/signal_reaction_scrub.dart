import 'dart:ui';

import 'signal_message_menu_geometry.dart';

/// Which emoji the finger is on while scrubbing the reaction bar, or null.
///
/// Ports `ConversationReactionOverlay#getSelectedIndexViaMotionEvent`. Three
/// gates, all of them load-bearing:
///
/// * **Deadzone** — nothing is picked until the finger has travelled
///   [SignalMenuMetrics.scrubDeadzone] from where the long press landed, so
///   letting go without moving opens the menu instead of firing a reaction.
/// * **Vertical band** — from the top of the bar down to a little below the
///   touch point, so the drag has to head *towards* the bar. A finger wandering
///   below the message picks nothing.
/// * **Horizontal slot** — the bar is [slots] equal segments; the pointer's x
///   picks one. Signal has no gaps here: the whole width is live.
///
/// Pure so the boundaries can be tested without a device.
int? signalScrubSelection({
  required Rect bar,
  required int slots,
  required Offset? pointer,
  required Offset touchDown,
}) {
  if (pointer == null || slots <= 0) return null;
  if ((pointer - touchDown).distance < SignalMenuMetrics.scrubDeadzone) {
    return null;
  }
  final bandBottom = touchDown.dy + SignalMenuMetrics.scrubBandBelowTouch;
  if (pointer.dy < bar.top || pointer.dy > bandBottom) return null;
  if (pointer.dx < bar.left || pointer.dx > bar.right) return null;

  final segment = bar.width / slots;
  if (segment <= 0) return null;
  final index = ((pointer.dx - bar.left) / segment).floor();
  return index.clamp(0, slots - 1);
}
