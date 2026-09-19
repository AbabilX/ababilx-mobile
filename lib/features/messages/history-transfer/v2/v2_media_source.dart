import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'v2_plan.dart';

/// Produces a media batch's plaintext stream, one 4 MiB piece at a time,
/// straight from the attachment files — media is never staged.
///
/// A file that vanished or changed since it was planned becomes `omitted`: its
/// bytes in the stream are zeros, so no chunk index is ever skipped (the server
/// finalizes only a gapless batch, which v1's uploader could deadlock on), and
/// the descriptor tells the destination to discard it. The caller persists the
/// plan whenever [omittedChanged] is set.
class V2MediaSource {
  V2MediaSource(this.plan);

  static const int chunkBytes = 4 * 1024 * 1024;

  final V2Plan plan;
  bool omittedChanged = false;

  List<({V2File file, V2Segment seg})> _segmentsOf(int batch) => [
    for (final file in plan.filesIn(batch))
      for (final seg in file.segments)
        if (seg.batch == batch) (file: file, seg: seg),
  ];

  Future<Uint8List> plaintext(V2PlannedBatch batch, int index) async {
    final start = index * chunkBytes;
    final end = (start + chunkBytes) < batch.streamBytes ? start + chunkBytes : batch.streamBytes;
    final out = Uint8List(end - start);
    for (final entry in _segmentsOf(batch.batch)) {
      final seg = entry.seg;
      final from = seg.streamOffset > start ? seg.streamOffset : start;
      final segEnd = seg.streamOffset + seg.length;
      final to = segEnd < end ? segEnd : end;
      if (to <= from || entry.file.status != 'available') continue;
      final bytes = await _read(entry.file, seg.fileOffset + (from - seg.streamOffset), to - from);
      if (bytes == null) {
        _omit(entry.file);
        continue;
      }
      out.setRange(from - start, to - start, bytes);
    }
    return out;
  }

  /// The segment's own hash, read again at finalize. A file whose size or
  /// modification time moved since planning is omitted instead: the bytes
  /// already uploaded may no longer be the bytes on disk.
  Future<String?> segmentHash(V2File file, V2Segment seg) async {
    if (file.status != 'available') return null;
    if (seg.length == 0) return sha256.convert(const []).toString();
    final bytes = await _read(file, seg.fileOffset, seg.length);
    if (bytes == null) {
      _omit(file);
      return null;
    }
    return sha256.convert(bytes).toString();
  }

  Future<Uint8List?> _read(V2File file, int offset, int length) async {
    RandomAccessFile? handle;
    try {
      final source = File(file.localPath);
      final stat = await source.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size != file.size ||
          stat.modified.millisecondsSinceEpoch != file.mtimeMs) {
        return null;
      }
      handle = await source.open();
      await handle.setPosition(offset);
      final bytes = await handle.read(length);
      return bytes.length == length ? bytes : null;
    } catch (_) {
      return null;
    } finally {
      await handle?.close();
    }
  }

  void _omit(V2File file) {
    if (file.status == 'omitted') return;
    file.status = 'omitted';
    omittedChanged = true;
  }
}
