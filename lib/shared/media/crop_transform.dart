import 'dart:ui';

/// The maths behind the image cropper, kept pure so the clamping can be
/// tested without a widget tree — an off-by-one here shows up as a photo that
/// can be dragged until the window contains a corner of blank canvas.
///
/// The window is a [Size] rather than a side length because an avatar and a
/// banner want the same gestures through different shapes: a square that will
/// be masked to a circle, and a wide strip. Everything below is written in
/// terms of both axes, so a square window behaves exactly as it always did.
class CropTransform {
  const CropTransform({
    required this.imageSize,
    required this.viewport,
    required this.scale,
    required this.offset,
  });

  /// Pixel size of the source image.
  final Size imageSize;

  /// The crop window, in logical pixels.
  final Size viewport;

  /// User zoom, 1 = the image exactly covering the window.
  final double scale;

  /// Pan, in logical pixels, of the image centre from the window centre.
  final Offset offset;

  static const double minScale = 1;
  static const double maxScale = 6;

  /// The scale at which the image exactly covers the window — the reference
  /// app's avatar cropper starts here, so opening the editor never shows a gap.
  /// "Cover" rather than "fit": whichever axis runs short decides.
  double get baseScale {
    if (imageSize.width <= 0 || imageSize.height <= 0) return 1;
    final byWidth = viewport.width / imageSize.width;
    final byHeight = viewport.height / imageSize.height;
    return byWidth > byHeight ? byWidth : byHeight;
  }

  double get effectiveScale => baseScale * scale.clamp(minScale, maxScale);

  Size get drawnSize => imageSize * effectiveScale;

  /// Pan limits: the image must always cover the whole window.
  Offset clamp(Offset candidate) {
    final drawn = drawnSize;
    final maxX = ((drawn.width - viewport.width) / 2).clamp(
      0.0,
      double.infinity,
    );
    final maxY = ((drawn.height - viewport.height) / 2).clamp(
      0.0,
      double.infinity,
    );
    return Offset(
      candidate.dx.clamp(-maxX, maxX),
      candidate.dy.clamp(-maxY, maxY),
    );
  }

  /// Pan that started at [start] and has moved [delta] since (current focal
  /// minus start focal — not the per-event `focalPointDelta`, which would
  /// snap the photo back every frame).
  Offset offsetAfterPan(Offset start, Offset delta) => clamp(start + delta);

  CropTransform copyWith({double? scale, Offset? offset}) => CropTransform(
    imageSize: imageSize,
    viewport: viewport,
    scale: (scale ?? this.scale).clamp(minScale, maxScale),
    offset: offset ?? this.offset,
  );

  /// Where the image is painted inside the window.
  Rect get destinationRect {
    final drawn = drawnSize;
    return Rect.fromCenter(
      center: Offset(viewport.width / 2, viewport.height / 2) + offset,
      width: drawn.width,
      height: drawn.height,
    );
  }

  /// The region of the source image the window is showing — the rectangle to
  /// copy when producing the cropped output.
  Rect get sourceRect {
    final eff = effectiveScale;
    final centre = Offset(
      imageSize.width / 2 - offset.dx / eff,
      imageSize.height / 2 - offset.dy / eff,
    );
    return Rect.fromCenter(
      center: centre,
      width: viewport.width / eff,
      height: viewport.height / eff,
    );
  }
}
