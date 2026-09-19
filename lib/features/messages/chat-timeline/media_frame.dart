import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../attachments/data/models/media_dimensions.dart';
import 'signal_bubble_metrics.dart';

/// Largest box inside [maxWidth] × [maxHeight] that keeps the file's aspect.
///
/// Tall (9:16) media shrinks **width** when height hits the ceiling — same
/// contain idea as web. Extreme panoramas still use the min-height floor and
/// keep full [maxWidth] (cropped via [BoxFit.cover]). Unmeasured files get
/// the default frame. Never resized while mounted — see `MediaFrameLock`.
Size soloMediaSize(
  MediaDimensions? size, {
  required double maxWidth,
  double maxHeight = SignalBubbleMetrics.mediaMaxHeight,
  double minWidth = 0,
  double minHeight = SignalBubbleMetrics.mediaMinHeight,
}) {
  if (size == null) {
    final side = SignalBubbleMetrics.mediaDefaultSize;
    return Size(side.clamp(minWidth > 0 ? minWidth : 0, maxWidth), side);
  }

  final ar = size.aspectRatio;
  late final double w;
  late final double h;
  if (maxWidth / maxHeight <= ar) {
    w = maxWidth;
    h = maxWidth / ar;
  } else {
    h = maxHeight;
    w = maxHeight * ar;
  }

  // Signal floor: very wide files stay full width and crop into min height.
  if (h < minHeight) {
    return Size(maxWidth, minHeight);
  }
  if (minWidth > 0 && w < minWidth) {
    final raised = minWidth;
    return Size(raised, (raised / ar).clamp(minHeight, maxHeight));
  }
  return Size(w, h);
}

/// Height of a solo picture or video at a fixed [width] (legacy helper).
/// Prefer [soloMediaSize] when both edges should follow the file's shape.
double soloMediaHeight(
  MediaDimensions? size, {
  required double width,
  double maxHeight = SignalBubbleMetrics.mediaMaxHeight,
}) => soloMediaSize(size, maxWidth: width, maxHeight: maxHeight).height;

/// Decode a picture at the size it is drawn, not the size it was shot.
///
/// A 12 MP photo decodes to ~48 MB and a 2048 px one to ~12 MB, for a bubble
/// 240 dp wide. Flutter's image cache holds 100 MB, so a chat of photos was
/// evicting and re-decoding on every pass, and each re-decode left the tile
/// empty for a few frames. Sized for BoxFit.cover in [box]: the short side is
/// covered, never upscaled. An unmeasured file decodes as it always did.
ImageProvider displaySizedImage(
  ImageProvider source, {
  required Size box,
  required MediaDimensions? size,
  required double devicePixelRatio,
}) {
  if (size == null || box.isEmpty) return source;
  final scale =
      math.max(box.width / size.width, box.height / size.height) *
      devicePixelRatio;
  if (scale >= 1) return source;
  return ResizeImage(source, width: (size.width * scale).ceil());
}

/// Fades a picture in over its placeholder the first time it decodes, the
/// way a native list does. A picture already in the image cache paints on its
/// first frame with no fade at all.
Widget fadeInImageFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: const Duration(milliseconds: 160),
    curve: Curves.easeOut,
    child: child,
  );
}
