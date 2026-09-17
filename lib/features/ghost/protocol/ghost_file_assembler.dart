import 'dart:typed_data';

import 'ghost_frames.dart';

/// One file finished arriving.
class GhostReceivedFile {
  const GhostReceivedFile(this.header, this.bytes);
  final GhostFileHeader header;
  final Uint8List bytes;
}

/// Progress of the file currently arriving, for the bubble's ring.
class GhostFileProgress {
  const GhostFileProgress(this.header, this.received);
  final GhostFileHeader header;
  final int received;
  double get fraction => header.size == 0 ? 1 : received / header.size;
}

/// Reassembles the peer's binary chunks into files, in memory only.
///
/// The buffer is allocated once at the announced size and filled in place, so
/// a burn can zero the one allocation that ever held the bytes rather than
/// hoping a growable builder's discarded copies are collected.
class GhostFileAssembler {
  GhostFileAssembler({this.sessionBudgetBytes = 200 * 1024 * 1024});

  /// Total bytes this session will hold from the peer before refusing more.
  final int sessionBudgetBytes;

  GhostFileHeader? _header;
  Uint8List? _buffer;
  int _offset = 0;
  int _accepted = 0;

  GhostFileHeader? get current => _header;

  /// Starts a file. False when it would blow the session budget — the chunks
  /// that follow are then dropped rather than buffered.
  bool begin(GhostFileHeader header) {
    _discard();
    if (_accepted + header.size > sessionBudgetBytes) return false;
    _header = header;
    _buffer = Uint8List(header.size);
    _offset = 0;
    return true;
  }

  /// Feeds one chunk. Returns the finished file on its last chunk, a
  /// [GhostFileProgress] otherwise, and null for a chunk nobody announced.
  Object? add(Uint8List chunk) {
    final header = _header, buffer = _buffer;
    if (header == null || buffer == null) return null;
    if (_offset + chunk.length > buffer.length) {
      // The peer sent more than it announced. Nothing partial is kept.
      _discard();
      return null;
    }
    buffer.setRange(_offset, _offset + chunk.length, chunk);
    _offset += chunk.length;
    if (_offset < buffer.length) return GhostFileProgress(header, _offset);
    _accepted += buffer.length;
    _header = null;
    _buffer = null;
    return GhostReceivedFile(header, buffer);
  }

  /// Drops a half-received file, zeroing what arrived.
  void _discard() {
    _buffer?.fillRange(0, _buffer!.length, 0);
    _header = null;
    _buffer = null;
    _offset = 0;
  }

  void clear() {
    _discard();
    _accepted = 0;
  }
}
