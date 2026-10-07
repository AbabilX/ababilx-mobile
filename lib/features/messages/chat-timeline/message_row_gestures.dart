import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Signal's gestures on a message row: a hold opens the menu, a double tap
/// copies, and a plain tap does nothing on its own.
///
/// The hold keeps reporting the finger, so one touch can press, drag onto an
/// emoji and release. While multi-select is up ([onHoldSelect] set) a hold
/// picks the row instead, as a tap does — Signal's action mode.
class MessageRowGestures extends StatelessWidget {
  const MessageRowGestures({
    super.key,
    required this.onTap,
    required this.onDoubleTap,
    required this.onHoldSelect,
    required this.onHoldStart,
    required this.onHoldMove,
    required this.onHoldEnd,
    this.onPressChanged,
    required this.child,
  });

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onHoldSelect;
  final ValueChanged<Offset> onHoldStart;
  final ValueChanged<Offset> onHoldMove;
  final VoidCallback onHoldEnd;

  /// A finger settled on the row (true, 100ms after touch-down — Signal's
  /// `SHRINK_BUBBLE_DELAY_MILLIS`) or left it / turned into something else.
  final ValueChanged<bool>? onPressChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final select = onHoldSelect;
    final press = onPressChanged;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: press == null ? null : (_) => press(true),
      onTapUp: press == null ? null : (_) => press(false),
      onTapCancel: press == null ? null : () => press(false),
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: select == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              select();
            },
      onLongPressStart: select != null
          ? null
          : (d) => onHoldStart(d.globalPosition),
      onLongPressMoveUpdate: select != null
          ? null
          : (d) => onHoldMove(d.globalPosition),
      onLongPressEnd: select != null ? null : (_) => onHoldEnd(),
      onLongPressCancel: select != null ? null : onHoldEnd,
      child: child,
    );
  }
}
