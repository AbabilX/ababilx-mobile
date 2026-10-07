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

  /// ~280–300 on the design canvas — hero face for incoming/outgoing.
  double get avatarDiameter => design(300).clamp(128.0, 176.0);

  double get nameFont => design(48).clamp(22.0, 30.0);

  double get statusFont => design(30).clamp(14.0, 18.0);

  /// Four mid-call toggles.
  double get controlDiameter => design(168).clamp(72.0, 96.0);

  double get controlIcon => design(64).clamp(30.0, 40.0);

  double get controlLabelFont => design(26).clamp(12.0, 15.0);

  /// Live hang-up circle under the four options. The largest seat on the
  /// screen: it is the one control nobody should have to aim for.
  double get hangupDiameter => design(232).clamp(84.0, 104.0);

  double get hangupIcon => design(96).clamp(36.0, 46.0);

  double get hangupLabelFont => design(24).clamp(12.0, 14.0);

  /// Post-call "Done" — compact pill, not a full-width bar.
  double get doneButtonHeight => design(72).clamp(36.0, 44.0);

  double get doneButtonWidth => design(280).clamp(120.0, 160.0);

  double get doneButtonFont => design(28).clamp(13.0, 15.0);

  /// Incoming Answer / Decline — large paired seats (ref: thumb-sized).
  double get incomingActionDiameter => design(220).clamp(92.0, 112.0);

  double get incomingActionIcon => design(88).clamp(40.0, 52.0);

  /// Gap between Decline and Answer — comfortable, not edge-spread.
  double get incomingActionGap => design(96).clamp(48.0, 72.0);

  /// Lift the pair above the gesture bar (larger = higher on screen).
  double incomingActionsBottom(double bottomInset) =>
      math.max(bottomInset, 0) + design(120).clamp(56.0, 88.0);

  double get sideMargin => design(36).clamp(12.0, 22.0);

  double get controlGap => design(20).clamp(8.0, 14.0);

  /// Space between two seats of the portrait deck, across and down.
  /// A share of the width, like the seats, so the deck keeps its proportions.
  double get seatGap => (layoutWidth * 0.065).clamp(16.0, 36.0);

  /// A portrait seat on a screen with room to spare: a fifth of the width.
  double get portraitSeatWanted => (layoutWidth * 0.2).clamp(56.0, 104.0);

  /// Seat diameter for the portrait deck (two rows of three).
  ///
  /// [portraitSeatWanted] grows with the screen; a narrow or short one — a
  /// small phone, split screen, a large font — gets less, so three seats fit
  /// across [width] and both rows with their labels fit in [height].
  double portraitSeat({
    required double width,
    required double height,
    required double labelHeight,
  }) {
    final across = (width - seatGap * 2) / 3;
    // One row = circle + gap to its label (16 at most) + the label.
    final down = (height - seatGap) / 2 - 16 - labelHeight;
    return math.min(across, down).clamp(48.0, portraitSeatWanted);
  }

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
