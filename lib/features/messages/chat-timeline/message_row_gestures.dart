import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Telegram's three gestures on a message row: a tap opens the menu, a double
/// tap reacts, a hold picks rows.
///
/// Where a hold cannot select ([onHoldSelect] null — a thread panel, which has
/// no selection bars), it opens the menu instead and keeps reporting the
/// finger, so one touch can still press, drag onto an emoji and release.
class MessageRowGestures extends StatelessWidget {
  const MessageRowGestures({
    super.key,
    required this.onTap,
    required this.onDoubleTap,
    required this.onHoldSelect,
    required this.onHoldStart,
    required this.onHoldMove,
    required this.onHoldEnd,
    required this.child,
  });

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onHoldSelect;
  final ValueChanged<Offset> onHoldStart;
  final ValueChanged<Offset> onHoldMove;
  final VoidCallback onHoldEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final select = onHoldSelect;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
