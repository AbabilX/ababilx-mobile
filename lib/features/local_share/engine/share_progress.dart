import 'dart:async';

/// Bytes moved so far for one message, across all of its files.
class ShareProgress {
  const ShareProgress(this.messageId, this.bytes, this.fileBytes);

  final String messageId;
  final int bytes;

  /// file id -> bytes of that file.
  final Map<String, int> fileBytes;
}

/// Collects per-chunk byte counts and publishes them at most once every
/// [interval] per message.
///
/// The transfer loops call [report] for every chunk — thousands of times a
/// second on a fast network. Publishing each one rebuilt the whole screen per
/// chunk and let two files of one message overwrite each other's numbers.
class ShareProgressHub {
  ShareProgressHub({this.interval = const Duration(milliseconds: 100)});

  final Duration interval;
  final _controller = StreamController<ShareProgress>.broadcast();
  final _files = <String, Map<String, int>>{};
  final _dirty = <String>{};
  Timer? _timer;

  Stream<ShareProgress> get stream => _controller.stream;

  ShareProgress? current(String messageId) {
    final files = _files[messageId];
    return files == null ? null : _snapshot(messageId, files);
  }

  void report(String messageId, String fileId, int bytes) {
    (_files[messageId] ??= {})[fileId] = bytes;
    _dirty.add(messageId);
    _timer ??= Timer(interval, _flush);
  }

  /// Publishes the last numbers now and forgets the message.
  void finish(String messageId) {
    final files = _files.remove(messageId);
    _dirty.remove(messageId);
    if (files != null && !_controller.isClosed) {
      _controller.add(_snapshot(messageId, files));
    }
  }

  void _flush() {
    _timer = null;
    final ids = _dirty.toList();
    _dirty.clear();
    for (final id in ids) {
      final files = _files[id];
      if (files != null && !_controller.isClosed) {
        _controller.add(_snapshot(id, files));
      }
    }
  }

  ShareProgress _snapshot(String id, Map<String, int> files) => ShareProgress(
    id,
    files.values.fold(0, (sum, b) => sum + b),
    Map.unmodifiable(Map.of(files)),
  );

  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
