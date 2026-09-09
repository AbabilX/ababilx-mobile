import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Buffers gzip output so it can be handed out in fixed-size pieces.
///
/// `GZipCodec.encoder` is a converter, not a stream we can pull from at our own
/// pace, so its output is collected here and drained by the writer. The sink is
/// closed exactly once — a second `close` on a `ByteConversionSink` throws, and
/// a half-closed member is an archive nothing can read.
class GzipChunker {
  GzipChunker() {
    _sink = gzip.encoder.startChunkedConversion(
      ByteConversionSink.withCallback((bytes) => _buffer.addAll(bytes)),
    );
  }

  late final Sink<List<int>> _sink;
  final List<int> _buffer = [];
  bool _finished = false;

  int get available => _buffer.length;

  void write(List<int> bytes) {
    if (_finished) return;
    _sink.add(bytes);
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    _sink.close();
  }

  Uint8List take(int max) {
    final count = max < _buffer.length ? max : _buffer.length;
    final out = Uint8List.fromList(_buffer.sublist(0, count));
    _buffer.removeRange(0, count);
    return out;
  }
}
