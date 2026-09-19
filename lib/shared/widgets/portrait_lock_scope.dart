import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the route in portrait while mounted; restores free rotation when the
/// **last** lock leaves.
///
/// Chat list, calls list, and conversation + IME are authored for a tall
/// viewport. Nested locks (list under conversation) share a depth counter so
/// popping the conversation does not unlock while the list is still showing.
///
/// Active call / video surfaces (`/call`, `/group-call`) must **not** wrap
/// with this; they need landscape. Those routes typically `go` and dispose
/// shell tabs, which drops depth to zero and unlocks.
class PortraitLockScope extends StatefulWidget {
  const PortraitLockScope({super.key, required this.child});

  final Widget child;

  /// Portrait-only preferred orientations for [SystemChrome].
  static const locked = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  /// App default after leaving every locked route.
  static const unlocked = DeviceOrientation.values;

  /// How many [PortraitLockScope]s are currently mounted. Visible for tests.
  @visibleForTesting
  static int get debugDepth => _depth;

  static int _depth = 0;

  @visibleForTesting
  static void debugResetDepth() => _depth = 0;

  @override
  State<PortraitLockScope> createState() => _PortraitLockScopeState();
}

class _PortraitLockScopeState extends State<PortraitLockScope> {
  @override
  void initState() {
    super.initState();
    PortraitLockScope._depth++;
    SystemChrome.setPreferredOrientations(PortraitLockScope.locked);
  }

  @override
  void dispose() {
    PortraitLockScope._depth--;
    if (PortraitLockScope._depth <= 0) {
      PortraitLockScope._depth = 0;
      SystemChrome.setPreferredOrientations(PortraitLockScope.unlocked);
    } else {
      SystemChrome.setPreferredOrientations(PortraitLockScope.locked);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
