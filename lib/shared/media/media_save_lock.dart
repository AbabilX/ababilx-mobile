import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// App-wide "nothing leaves the app from here" hold, for a private group
/// (server 0154).
///
/// Every viewer opens as a dialog on the root navigator, outside the chat's
/// widget tree, so an InheritedWidget cannot reach it. The chat and details
/// screens of a private group hold this instead, and every media dock reads it:
/// while it is held, Save and Share are not drawn — for a photo, a video, a
/// file, a group picture or a member's avatar alike.
///
/// Holds are counted, the way FLAG_SECURE holds are: the chat and its details
/// screen are both on the stack, and the second one closing must not unlock
/// the first.
abstract final class MediaSaveLock {
  static final ValueNotifier<int> _holds = ValueNotifier(0);

  static ValueListenable<int> get listenable => _holds;

  static bool get held => _holds.value > 0;

  static void _take() => _holds.value++;

  static void _release() {
    if (_holds.value > 0) _holds.value--;
  }

  @visibleForTesting
  static void resetForTest() => _holds.value = 0;
}

/// Holds [MediaSaveLock] while [active] and this widget is mounted. Takes at
/// most one hold and gives back exactly that one.
class MediaSaveLockScope extends StatefulWidget {
  const MediaSaveLockScope({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<MediaSaveLockScope> createState() => _MediaSaveLockScopeState();
}

class _MediaSaveLockScopeState extends State<MediaSaveLockScope> {
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(MediaSaveLockScope old) {
    super.didUpdateWidget(old);
    _sync(widget.active);
  }

  @override
  void dispose() {
    _sync(false);
    super.dispose();
  }

  void _sync(bool lock) {
    if (_held == lock) return;
    _held = lock;
    lock ? MediaSaveLock._take() : MediaSaveLock._release();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
