import 'dart:ui' as ui;

import '../../../shared/media/video_thumbnail.dart';
import '../data/models/media_dimensions.dart';

/// Reads a stored file's drawn size without decoding its pixels.
typedef MediaMeasure =
    Future<MediaDimensions?> Function(String path, {required bool video});

/// A picture's size comes from its header: `ImageDescriptor.encoded` parses
/// the header and allocates no pixels, and it answers through the same codec
/// that later decodes the file, so EXIF orientation is applied the same way
/// both times. A video's size is its poster frame's, which is also what the
/// bubble draws; the frame is extracted and cached natively anyway
/// (`VideoThumbnails`), so this costs the tile nothing extra. Android only for
/// video; elsewhere, and for anything unreadable, the answer is null and the
/// tile keeps its default frame.
Future<MediaDimensions?> measureMediaFile(
  String path, {
  required bool video,
}) async {
  if (video) {
    final thumb = await VideoThumbnails.forFile(path);
    return thumb == null
        ? null
        : MediaDimensions.tryCreate(thumb.width, thumb.height);
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return MediaDimensions.tryCreate(descriptor.width, descriptor.height);
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
