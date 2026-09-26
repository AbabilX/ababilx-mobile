import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A memory photo's byte budget. The card shows it at most ~340dp wide, so
/// past this the extra bytes buy nothing on screen — they cost the upload,
/// the storage and the receiver's data, and a small file is what lets
/// auto-download take it on cellular before the card is opened.
const khaamPhotoMaxBytes = 350 * 1024;

/// [jpeg] squeezed under [maxBytes]: quality first, then size. Returned as is
/// when it already fits. Runs off the UI isolate.
Future<Uint8List> compressKhaamPhoto(
  Uint8List jpeg, {
  int maxBytes = khaamPhotoMaxBytes,
}) async {
  if (jpeg.length <= maxBytes) return jpeg;
  return compute(_squeeze, _Job(jpeg, maxBytes));
}

class _Job {
  const _Job(this.bytes, this.maxBytes);
  final Uint8List bytes;
  final int maxBytes;
}

const _qualities = [76, 68, 60];
const _widths = [1280, 1080, 900, 720];

Uint8List _squeeze(_Job job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return job.bytes;
  var best = job.bytes;
  for (final width in _widths) {
    if (width > decoded.width && width != _widths.first) continue;
    final frame = decoded.width > width
        ? img.copyResize(
            decoded,
            width: width,
            interpolation: img.Interpolation.average,
          )
        : decoded;
    for (final quality in _qualities) {
      final out = img.encodeJpg(frame, quality: quality);
      if (out.length < best.length) best = out;
      if (out.length <= job.maxBytes) return out;
    }
  }
  return best;
}
