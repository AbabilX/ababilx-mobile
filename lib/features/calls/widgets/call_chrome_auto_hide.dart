import 'dart:async';

import 'package:flutter/material.dart';

/// Idle fade for 1:1 call chrome while watching remote video / screen share.
///
/// Audio-only leaves [enabled] false so Mute · End stay visible. On a stage,
/// chrome hides after [hideAfter]; a tap on the empty stage reveals it again
/// (or hides it if already visible). Local PiP stays outside this widget.
class CallChromeAutoHide extends StatefulWidget {
  const CallChromeAutoHide({
    super.key,
    required this.enabled,
    required this.child,
    this.hideAfter = const Duration(seconds: 4),
    this.fade = const Duration(milliseconds: 220),
  });

  /// True when remote video or screen share fills the stage.
  final bool enabled;

  /// Minimize, peer caption, notes, and the control deck.
  final Widget child;

  final Duration hideAfter;
  final Duration fade;

  @override
  State<CallChromeAutoHide> createState() => _CallChromeAutoHideState();
}

class _CallChromeAutoHideState extends State<CallChromeAutoHide> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _armHide();
  }

  @override
  void didUpdateWidget(CallChromeAutoHide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _cancelHide();
      if (!_visible) setState(() => _visible = true);
      return;
    }
    if (!oldWidget.enabled && widget.enabled) {
      setState(() => _visible = true);
      _armHide();
    }
  }

  @override
  void dispose() {
    _cancelHide();
    super.dispose();
  }

  void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _armHide() {
    _cancelHide();
    if (!widget.enabled || !_visible) return;
    _hideTimer = Timer(widget.hideAfter, () {
      if (!mounted || !widget.enabled) return;
      setState(() => _visible = false);
    });
  }

  void _onStageTap() {
    if (!widget.enabled) return;
    setState(() => _visible = !_visible);
    if (_visible) {
      _armHide();
    } else {
      _cancelHide();
    }
  }

  void _onChromePointer() {
    if (!widget.enabled || !_visible) return;
    _armHide();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.enabled)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onStageTap,
              child: const SizedBox.expand(),
            ),
          ),
        AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: widget.fade,
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !_visible,
            child: Listener(
              behavior: HitTestBehavior.deferToChild,
              onPointerDown: (_) => _onChromePointer(),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
