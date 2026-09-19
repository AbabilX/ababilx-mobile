import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Layout numbers for the 1:1 call overlay, authored against 1080 × 1920.
///
/// Scale always uses the narrower edge so landscape does not inflate the
/// control circles — seats stay the same size; only inners reorient.
class CallOverlayMetrics {
  const CallOverlayMetrics._(this.size, this.layoutWidth);

  factory CallOverlayMetrics.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return CallOverlayMetrics._(size, math.min(size.width, size.height));
  }

  final Size size;

  /// Narrow edge — portrait width, or landscape height.
  final double layoutWidth;

  static const designWidth = 1080.0;
  static const designHeight = 1920.0;

  double get _scale => layoutWidth / designWidth;

  double design(double px) => px * _scale;

  /// ~220–250 on the design canvas.
  double get avatarDiameter => design(240).clamp(100.0, 148.0);

  double get nameFont => design(48).clamp(22.0, 30.0);

  double get statusFont => design(30).clamp(14.0, 18.0);

  /// Four mid-call toggles — intentionally larger than End.
  double get controlDiameter => design(168).clamp(72.0, 96.0);

  double get controlIcon => design(64).clamp(30.0, 40.0);

  double get controlLabelFont => design(26).clamp(12.0, 15.0);

  /// Live hang-up circle under the four options.
  double get hangupDiameter => design(128).clamp(58.0, 72.0);

  double get hangupIcon => design(52).clamp(26.0, 32.0);

  double get hangupLabelFont => design(24).clamp(12.0, 14.0);

  /// Post-call "Done" — compact pill, not a full-width bar.
  double get doneButtonHeight => design(72).clamp(36.0, 44.0);

  double get doneButtonWidth => design(280).clamp(120.0, 160.0);

  double get doneButtonFont => design(28).clamp(13.0, 15.0);

  /// Incoming Answer / Decline stay thumb-sized (not the tiny End).
  double get incomingActionDiameter => design(148).clamp(68.0, 84.0);

  double get incomingActionIcon => design(62).clamp(30.0, 36.0);

  double get sideMargin => design(36).clamp(12.0, 22.0);

  double get controlGap => design(20).clamp(8.0, 14.0);

  /// Top of the avatar circle — a touch below 1/3 so it clears the chevron.
  double get avatarTop => size.height * 0.34 - avatarDiameter / 2;

  /// Top of the four-button row — ~74% of screen height.
  double get controlsTop => size.height * 0.74;

  /// Top of the hang-up circle — ~86% of screen height.
  double get hangupTop => size.height * 0.86;

  /// Keep the hang-up label above the system gesture inset.
  double hangupBottomClearance(double bottomInset) =>
      math.max(bottomInset + design(52).clamp(20.0, 36.0), design(60));

  /// Safe clamp when a short landscape height makes max < min.
  static double clampTop(
    double value, {
    required double min,
    required double max,
  }) {
    if (max < min) return min;
    return value.clamp(min, max);
  }
}
