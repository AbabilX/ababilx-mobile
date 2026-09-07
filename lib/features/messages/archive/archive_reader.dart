import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'archive_frames.dart';
import 'archive_key.dart';

/// Raised when an archive stops before its terminator, or carries fewer frames
/// than it says it does. Always a refusal to restore, never a partial one — a
/// silently short history is worse than a failed restore, because nothing
/// afterwards can tell the two apart.
class ArchiveTruncatedError implements Exception {
  const ArchiveTruncatedError(this.message);

  final String message;

  @override
  String toString() => 'ArchiveTruncatedError: $message';
}

/// Reads an archive back: `chunk -> AES-GCM open -> gunzip -> NDJSON frames`.
///
/// Chunks must be fed in the order they were written. Each one is opened
/// against its own index, so feeding them out of order or dropping the tail
/// fails the tag rather than yielding a shorter, plausible history — which is
/// exactly the failure a restore must never accept silently.
///
/// A frame is only ever *skipped*, never fatal: an unknown `t` is a newer app's
/// frame type, and an unparseable line is one lost row. The authenticity check
/// already happened at the chunk boundary, so past that point the right
/// behaviour is to restore everything that can be read.
class ArchiveReader {
  ArchiveReader({required this.key, required this.onFrame});

  final SecretKey key;
  final Future<void> Function(ArchiveFrame frame) onFrame;

  final List<int> _plain = [];
  int _index = 0;
  int _skipped = 0;
  int _read = 0;
  bool _sawEnd = false;

  int get chunksRead => _index;
  int get framesSkipped => _skipped;

  Future<void> addChunk(ArchiveChunk chunk) async {
    _plain.addAll(await ArchiveKey.open(key, _index, chunk));
    _index++;
  }

  /// Decompresses everything fed so far and replays it.
  ///
  /// gzip is decoded once at the end rather than incrementally: a gzip member
  /// cannot be decoded past its final block until that block arrives, so a
  /// partial archive has no partial answer to give.
  Future<void> finish() async {
    if (_plain.isEmpty) return;
    final text = utf8.decode(gzip.decode(Uint8List.fromList(_plain)));
    for (final line in const LineSplitter().convert(text)) {
      final frame = ArchiveFrame.fromLine(line);
      if (frame == null) {
        _skipped++;
        continue;
      }
      if (frame.type == ArchiveFrame.end) {
        _sawEnd = true;
        final declared = frame.data['frames'];
        if (declared is int && declared != _read) {
          throw ArchiveTruncatedError(
            'archive declares $declared frames, read $_read',
          );
        }
        continue;
      }
      _read++;
      await onFrame(frame);
    }
    if (!_sawEnd) {
      throw const ArchiveTruncatedError('archive has no end frame');
    }
  }
}
