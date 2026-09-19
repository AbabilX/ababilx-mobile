import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the route in portrait while mounted; restores free rotation on leave.
///
/// Chat composer + keyboard are authored for a tall viewport. Landscape + IME
/// was overflowing the timeline by a few pixels — lock here rather than
/// stretching every chat layout to landscape.
///
/// Call / video surfaces must **not** wrap with this; they need landscape.
class PortraitLockScope extends StatefulWidget {
  const PortraitLockScope({super.key, required this.child});

  final Widget child;

  /// Portrait-only preferred orientations for [SystemChrome].
  static const locked = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  /// App default after leaving a locked route.
  static const unlocked = DeviceOrientation.values;

  @override
  State<PortraitLockScope> createState() => _PortraitLockScopeState();
}

class _PortraitLockScopeState extends State<PortraitLockScope> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(PortraitLockScope.locked);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(PortraitLockScope.unlocked);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
