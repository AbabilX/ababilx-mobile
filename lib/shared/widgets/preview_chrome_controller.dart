import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'image_preview_chrome.dart';

/// Title bar + capsule visibility for every fullscreen preview.
///
/// Scroll into the content hides chrome. Idle of [idle] does the same.
/// A tap toggles. Touching the dock / scrubber shows it and restarts the timer.
class PreviewChrome {
  PreviewChrome({
    required this.onChanged,
    this.idle = ImagePreviewChrome.idle,
  });

  final VoidCallback onChanged;
  final Duration idle;

  bool visible = true;
  Timer? _timer;

  void dispose() => _timer?.cancel();

  void reveal() {
    _timer?.cancel();
    if (!visible) {
      visible = true;
      onChanged();
    }
    _armIdle();
  }

  void hide() {
    _timer?.cancel();
    if (!visible) return;
    visible = false;
    onChanged();
  }

  void toggle() => visible ? hide() : reveal();

  /// Vertical scroll — swipe up into the document hides the bars.
  bool onScroll(Notification notification) {
    if (notification is! UserScrollNotification) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.direction == ScrollDirection.forward) hide();
    if (notification.direction == ScrollDirection.reverse) reveal();
    return false;
  }

  /// Pinch / pan on a photo hides chrome so the picture has the screen.
  void onContentPan() => hide();

  void _armIdle() {
    if (idle <= Duration.zero) return;
    _timer?.cancel();
    _timer = Timer(idle, hide);
  }
}
