import 'dart:math' as math;

import 'package:flutter/painting.dart' show Size;

/// libwebrtc's `RendererCommon.getDisplaySize`, in Dart — the rule the
/// reference app uses for a camera tile (`SCALE_ASPECT_FILL` when the video and
/// the view share an orientation, `SCALE_ASPECT_BALANCED` when they do not).
///
/// It exists because "fill the box" and "fit in the box" are both wrong when a
/// laptop's 16:9 camera lands in a phone's portrait call screen. Filling crops
/// about 40% off each side — the caller's face leaves the frame and what is
/// left reads as a vertical slice of one shoulder. Fitting letterboxes so hard
/// that a person occupies a sixth of the screen.
///
/// Balanced is the middle: crop, but never past [_minVisibleFraction] of the
/// frame, and letterbox whatever the crop could not cover. The returned size is
/// the box the video should be drawn into with a cover fit; centre it and paint
/// black behind it.
const double _minVisibleFraction = 0.5625;

Size videoDisplaySize(Size box, double videoAspect) {
  if (box.width <= 0 || box.height <= 0 || videoAspect <= 0) return box;
  final boxAspect = box.width / box.height;
  // Same side of 1.0 = same orientation. Two landscapes of different shapes
  // still crop freely: that difference is small enough that nobody notices,
  // and the reference app treats it the same way.
  if ((videoAspect > 1.0) == (boxAspect > 1.0)) return box;
  return Size(
    math.min(box.width, box.height / _minVisibleFraction * videoAspect),
    math.min(box.height, box.width / _minVisibleFraction / videoAspect),
  );
}
