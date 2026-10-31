import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The finger, still down after a long press, handed to the open overlay.
///
/// The reference app keeps receiving MotionEvents on the conversation list and
/// forwards them to the overlay, so one gesture can press a message, drag onto
/// an emoji and release to react. Flutter routes the same way for free: the
/// recogniser that fired the long press keeps the pointer, so
/// `onLongPressMoveUpdate` still arrives while the dialog is up. This carries
/// those positions across.
class MessageMenuPointer {
  MessageMenuPointer(this.touchDown);

  /// Where the long press landed. The scrub deadzone is measured from here.
  final Offset touchDown;

  /// Current global position, or null once the finger lifts.
  final ValueNotifier<Offset?> position = ValueNotifier<Offset?>(null);

  /// Set when the finger lifts, so the overlay can tell "not moving" from
  /// "gone" — a release over an emoji reacts, a release anywhere else leaves
  /// the menu open to be tapped.
  final ValueNotifier<bool> released = ValueNotifier<bool>(false);

  void moveTo(Offset global) => position.value = global;

  void release() {
    position.value = null;
    released.value = true;
  }

  void dispose() {
    position.dispose();
    released.dispose();
  }
}
