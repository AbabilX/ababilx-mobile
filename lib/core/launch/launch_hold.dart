import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

/// The reference app's launch: the system splash (icon on the app's background)
/// stays up until the first real screen is ready, and that screen is the chat
/// list — no in-app loading screen between them.
///
/// Flutter's Android embedding keeps the launch window until the first frame
/// reaches the engine, so holding that frame is what keeps the splash. It is
/// held only until auth has read the saved session (local storage), which is
/// what decides chats or login. Before this the router waited on `/login`,
/// and every launch painted the login picture with a pulsing logo.
abstract final class LaunchHold {
  /// A stuck read must never leave the phone on the splash.
  static const _ceiling = Duration(seconds: 3);

  static bool _held = false;

  /// Before `runApp`.
  static void hold() {
    if (_held) return;
    _held = true;
    WidgetsBinding.instance.deferFirstFrame();
    Timer(_ceiling, release);
  }

  static void release() {
    if (!_held) return;
    _held = false;
    WidgetsBinding.instance.allowFirstFrame();
  }
}

/// Lets the first frame through once auth has decided where to go.
class LaunchHoldRelease extends ConsumerStatefulWidget {
  const LaunchHoldRelease({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LaunchHoldRelease> createState() => _LaunchHoldReleaseState();
}

class _LaunchHoldReleaseState extends ConsumerState<LaunchHoldRelease> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (_, next) {
      if (next.isLoading) return;
      // The redirect runs on this same change: let the frame that builds the
      // destination happen (still held), then show it.
      final binding = WidgetsBinding.instance;
      binding.addPostFrameCallback((_) => LaunchHold.release());
      binding.scheduleFrame();
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
