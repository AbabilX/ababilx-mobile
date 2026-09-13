import 'package:flutter/material.dart';

/// Signal-Android's media-preview chrome (`fragment_media_preview`).
///
/// Forced dark — the viewer owns the screen the way Signal's activity does.
/// Bars are the dark surface at 87% so the photo still reads through them.
abstract final class ImagePreviewChrome {
  static const background = Color(0xFF1B1C1F);
  static const bar = Color(0xDE1B1C1F);
  static const capsule = Color(0xF21B1C1F);
  static const fadeDuration = Duration(milliseconds: 180);
  static const railSize = 46.0;
  static const railThumb = 44.0;
  static const railGap = 8.0;
  static const railRadius = 8.0;
  static const actionSize = 48.0;

  static Widget layer({required bool visible, required Widget child}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: fadeDuration,
        child: child,
      ),
    );
  }
}
