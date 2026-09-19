import 'package:equatable/equatable.dart';

/// A picture's pixel size as it is drawn — EXIF orientation already applied —
/// or a video's poster frame.
///
/// What lets the timeline hold a photo at its final height before a single
/// pixel of it is decoded. The server carries no dimensions for an
/// attachment, so this is measured on the device from the stored file (see
/// `AttachmentDimensionReader`) and kept in `attachment_blobs`.
class MediaDimensions extends Equatable {
  const MediaDimensions(this.width, this.height);

  final int width;
  final int height;

  /// Null for anything that cannot be a real picture, including a column that
  /// was never written.
  static MediaDimensions? tryCreate(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return MediaDimensions(width, height);
  }

  /// Width over height.
  double get aspectRatio => width / height;

  @override
  List<Object?> get props => [width, height];
}
