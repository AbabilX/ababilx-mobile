import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'archive_frames.dart';
import 'archive_key.dart';
import 'gzip_chunker.dart';

/// Turns a stream of frames into sealed chunks, without ever holding the whole
/// history in memory.
///
/// The pipeline is `frames -> NDJSON -> gzip -> chunk -> AES-GCM`, and the
/// order of the middle two is not interchangeable: **compress before you
/// encrypt.** Ciphertext is indistinguishable from random and does not
/// compress, so gzipping afterwards would cost CPU and save nothing.
///
/// Chunking is what makes a large archive uploadable and resumable. Each chunk
/// is sealed under its own index (see [ArchiveKey.seal]), so a chunk is valid
/// only in the position it was written to and a truncated upload cannot read as
/// a complete, shorter history.
class ArchiveWriter {
  ArchiveWriter({
    required this.key,
    required this.onChunk,
    this.chunkBytes = defaultChunkBytes,
  }) : _gzip = GzipChunker();

  /// 4 MiB. Large enough that a long history is not thousands of requests,
  /// small enough that a failed upload re-sends little and a phone never holds
  /// much at once.
  static const int defaultChunkBytes = 4 * 1024 * 1024;

  final SecretKey key;
  final int chunkBytes;

  /// Called with each sealed chunk in order. Awaited, so a slow upload applies
  /// back-pressure to the export instead of queueing chunks in memory.
  final Future<void> Function(int index, ArchiveChunk chunk) onChunk;

  final GzipChunker _gzip;
  int _index = 0;
  int _frames = 0;

  int get chunksWritten => _index;
  int get framesWritten => _frames;

  Future<void> add(ArchiveFrame frame) async {
    _gzip.write(utf8.encode('${jsonEncode(frame.toJson())}\n'));
    _frames++;
    while (_gzip.available >= chunkBytes) {
      await _emit(_gzip.take(chunkBytes));
    }
  }

  /// Writes the terminator, flushes the gzip trailer, and emits what is left.
  ///
  /// Must be called. Without it the archive has no end frame and every reader
  /// will — correctly — refuse it as truncated.
  Future<void> close() async {
    _gzip.write(
      utf8.encode(
        '${jsonEncode(ArchiveFrame.endFrame(frames: _frames).toJson())}\n',
      ),
    );
    _gzip.finish();
    while (_gzip.available > 0) {
      await _emit(_gzip.take(chunkBytes));
    }
  }

  Future<void> _emit(Uint8List bytes) async {
    final chunk = await ArchiveKey.seal(key, _index, bytes);
    await onChunk(_index, chunk);
    _index++;
  }
}
