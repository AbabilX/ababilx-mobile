import 'dart:ui';

/// The maths behind the avatar cropper, kept pure so the clamping can be
/// tested without a widget tree — an off-by-one here shows up as a photo that
/// can be dragged until the circle contains a corner of blank canvas.
class CropTransform {
  const CropTransform({
    required this.imageSize,
    required this.viewport,
    required this.scale,
    required this.offset,
  });

  /// Pixel size of the source image.
  final Size imageSize;

  /// Side of the square crop window, in logical pixels.
  final double viewport;

  /// User zoom, 1 = the image exactly covering the window.
  final double scale;

  /// Pan, in logical pixels, of the image centre from the window centre.
  final Offset offset;

  static const double minScale = 1;
  static const double maxScale = 6;

  /// The scale at which the shorter edge exactly fills the window — Signal's
  /// avatar cropper starts here, so opening the editor never shows a gap.
  double get baseScale {
    final shortest = imageSize.shortestSide;
    if (shortest <= 0) return 1;
    return viewport / shortest;
  }

  double get effectiveScale => baseScale * scale.clamp(minScale, maxScale);

  Size get drawnSize => imageSize * effectiveScale;

  /// Pan limits: the image must always cover the whole window.
  Offset clamp(Offset candidate) {
    final drawn = drawnSize;
    final maxX = ((drawn.width - viewport) / 2).clamp(0.0, double.infinity);
    final maxY = ((drawn.height - viewport) / 2).clamp(0.0, double.infinity);
    return Offset(
      candidate.dx.clamp(-maxX, maxX),
      candidate.dy.clamp(-maxY, maxY),
    );
  }

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
      center: Offset(viewport / 2, viewport / 2) + offset,
      width: drawn.width,
      height: drawn.height,
    );
  }

  /// The region of the source image the window is showing — the rectangle to
  /// copy when producing the cropped output.
  Rect get sourceRect {
    final visible = viewport / effectiveScale;
    final centre = Offset(
      imageSize.width / 2 - offset.dx / effectiveScale,
      imageSize.height / 2 - offset.dy / effectiveScale,
    );
    return Rect.fromCenter(center: centre, width: visible, height: visible);
  }
}
