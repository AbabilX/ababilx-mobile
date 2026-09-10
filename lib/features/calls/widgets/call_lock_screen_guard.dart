import 'dart:async';

import 'package:flutter/material.dart';

import '../native/android_call_lock_screen.dart';

/// Keeps everything but the call behind the lock screen.
///
/// While native has the app over the keyguard ([CallLockState.exposed]), any
/// route that is not the live call's own screen is painted black in the very
/// frame it would have shown — Dart draws before a message could reach native,
/// so this cannot wait for it. Once native has dropped the app back behind the
/// keyguard, its own cover takes over and this lets go. See `CallLockScreen.kt`.
class CallLockScreenGuard extends StatefulWidget {
  const CallLockScreenGuard({
    super.key,
    required this.callVisible,
    required this.callLive,
    required this.child,
  });

  /// A live call's own screen is the top route.
  final bool callVisible;

  /// A call is ringing, connecting or up, on screen or not.
  final bool callLive;
  final Widget child;

  @override
  State<CallLockScreenGuard> createState() => _CallLockScreenGuardState();
}

class _CallLockScreenGuardState extends State<CallLockScreenGuard> {
  var _lock = CallLockState.unlocked;
  var _revision = 0;

  bool get _supported => AndroidCallLockScreen.supported;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    AndroidCallLockScreen.listen(_onChanged);
    unawaited(_read());
    _publish();
  }

  void _onChanged(CallLockState state) {
    if (!mounted) return;
    _revision++;
    setState(() => _lock = state);
  }

  Future<void> _read() async {
    final revision = _revision;
    final state = await AndroidCallLockScreen.read();
    if (mounted && revision == _revision) setState(() => _lock = state);
  }

  @override
  void didUpdateWidget(CallLockScreenGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_supported) return;
    if (widget.callVisible && !oldWidget.callVisible) {
      // Native raises the flag when it hears this. Until it answers, a call
      // screen that goes away again must still count as over the lock.
      _lock = _lock.copyWith(overLock: true);
    }
    if (widget.callVisible != oldWidget.callVisible ||
        widget.callLive != oldWidget.callLive) {
      _publish();
    }
  }

  /// After the frame: native lifts its cover when it hears the call is
  /// visible, so the call must already be painted — and when it hears the
  /// call is gone, the mask must already be.
  void _publish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        AndroidCallLockScreen.setCallState(
          visible: widget.callVisible,
          live: widget.callLive,
        ),
      );
    });
  }

  @override
  void dispose() {
    if (_supported) {
      AndroidCallLockScreen.listen(null);
      unawaited(
        AndroidCallLockScreen.setCallState(visible: false, live: false),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _supported && _lock.exposed && !widget.callVisible;
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        Offstage(offstage: hidden, child: widget.child),
        if (hidden) const ColoredBox(color: Colors.black),
      ],
    );
  }
}
