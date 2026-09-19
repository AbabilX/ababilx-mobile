import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../attachments/data/models/media_dimensions.dart';
import 'signal_bubble_metrics.dart';

/// Height of a solo picture or video that fills [width]: the file's own
/// shape, held between Signal's `media_bubble_min_height` and [maxHeight].
/// With no measured shape it is the default frame, and the media is cropped
/// into it — never resized while mounted, see `MediaFrameLock`.
double soloMediaHeight(
  MediaDimensions? size, {
  required double width,
  double maxHeight = SignalBubbleMetrics.mediaMaxHeight,
}) {
  if (size == null) return SignalBubbleMetrics.mediaDefaultSize;
  return (width / size.aspectRatio).clamp(
    SignalBubbleMetrics.mediaMinHeight,
    maxHeight,
  );
}

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
