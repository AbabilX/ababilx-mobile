import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../protocol/ghost_frames.dart';

/// Streams files over the data channel one at a time, respecting the
/// channel's buffer.
///
/// SCTP accepts sends far faster than it delivers them. Pushing a 50 MB file
/// in a tight loop fills the native buffer, and past its limit libwebrtc
/// CLOSES the channel — which Ghost Chat reads as the peer leaving, and burns.
/// So the sender waits whenever more than [_highWater] is queued.
class GhostFileSender {
  GhostFileSender(this._channel);

  final RTCDataChannel Function() _channel;
  Future<void> _queue = Future.value();
  bool _cancelled = false;

  static const _highWater = 1024 * 1024;
  static const _checkEvery = 8;

  /// Queues [bytes] behind any file already sending. [onProgress] reports
  /// bytes handed to the channel; the future completes when the last chunk is.
  Future<bool> send(
    GhostFileHeader header,
    Uint8List bytes, {
    required void Function(int sent) onProgress,
  }) {
    final done = Completer<bool>();
    _queue = _queue.then((_) async {
      done.complete(await _sendOne(header, bytes, onProgress));
    });
    return done.future;
  }

  Future<bool> _sendOne(
    GhostFileHeader header,
    Uint8List bytes,
    void Function(int sent) onProgress,
  ) async {
    try {
      final channel = _channel();
      await channel.send(RTCDataChannelMessage(header.encode()));
      var sent = 0, index = 0;
      while (sent < bytes.length) {
        if (_cancelled) return false;
        if (index++ % _checkEvery == 0) await _drain(channel);
        final end = (sent + ghostChunkBytes).clamp(0, bytes.length);
        // A view, not a copy: the only buffer holding the file stays the one
        // the burn zeroes.
        await channel.send(
          RTCDataChannelMessage.fromBinary(
            Uint8List.sublistView(bytes, sent, end),
          ),
        );
        sent = end;
        onProgress(sent);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _drain(RTCDataChannel channel) async {
    while (!_cancelled) {
      final buffered = await channel.getBufferedAmount();
      if (buffered < _highWater) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  void cancel() => _cancelled = true;
}
