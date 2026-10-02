import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Turns a downloaded picture into the small file the avatar store keeps.
///
/// The biggest avatar drawn is the 96dp details header — 288 px on a 3x
/// screen — so nothing beyond that short side is ever shown. A group photo is
/// often a full camera frame, and decoding 12 MP for a 52dp chat-list tile is
/// most of what made pictures arrive late. Shrunk once here, every later
/// launch decodes a few hundred pixels. WhatsApp keeps a thumbnail per
/// contact for the same reason.
class AvatarThumb {
  const AvatarThumb._();

  /// Short side of the stored picture, in pixels.
  static const int side = 288;

  /// A file already this small is kept as it came (JPEG stays JPEG).
  static const int _keepBytes = 300 * 1024;

  /// The bytes to store, or null when [bytes] is not a decodable picture.
  static Future<Uint8List?> shrink(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0) return null;
      final short = math.min(w, h);
      if (short <= side && bytes.length <= _keepBytes) return bytes;
      final scale = math.min(1.0, side / short);
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (w * scale).round()),
        targetHeight: math.max(1, (h * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
