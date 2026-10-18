import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../calls/data/models/ice_server.dart';
import 'live_answers.dart';
import 'live_peer.dart';
import 'live_wire.dart';

/// One open live history connection: the peer, the framing in both
/// directions, and the two clocks that end it.
///
/// Every frame out goes through one queue, so a page asked for while a file
/// is streaming goes out between two of the file's slices instead of after
/// the whole file. The browser pings every 2 s; silence for [lostAfter] is a
/// browser that went away. No REQUEST for [idleAfter] ends the connection
/// too, so the foreground service is not held for a tab left open overnight
/// — the browser wakes the phone again when it needs something.
class LiveChannel {
  LiveChannel({
    required this.onSignal,
    required this.onOpen,
    required this.onClosed,
    required LiveAnswers Function(LiveSend send) answers,
  }) {
    _answers = answers(send);
  }

  final void Function(String kind, Map<String, dynamic> payload) onSignal;
  final VoidCallback onOpen;
  final VoidCallback onClosed;
  late final LiveAnswers _answers;

  static const lostAfter = Duration(seconds: 20);
  static const idleAfter = Duration(minutes: 10);
  static const _highWater = 1 << 20;

  LivePeer? _peer;
  final _assembler = LiveAssembler();
  Future<void> _queue = Future.value();
  int _nextFrame = 1;
  Timer? _lost;
  Timer? _idle;
  bool _closed = false;

  bool get open => _peer?.open ?? false;
  LiveAnswers get answers => _answers;

  Future<void> start(List<IceServer> iceServers) async {
    final peer = LivePeer(
      onSignal: onSignal,
      onOpen: () {
        _heard(request: true);
        onOpen();
      },
      onClosed: close,
      onBinary: _receive,
    );
    _peer = peer;
    await peer.start(iceServers);
  }

  Future<void> handleSignal(String kind, Map<String, dynamic> payload) async =>
      _peer?.handleSignal(kind, payload);

  Future<void> send(Map<String, dynamic> header, [List<int>? body]) {
    final run = _queue.then((_) async {
      final peer = _peer;
      if (peer == null || !peer.open) throw StateError('channel closed');
      final frame = encodeLiveFrame(header, body);
      final id = _nextFrame++;
      var n = 0;
      for (final piece in livePieces(id, frame)) {
        // SCTP takes sends far faster than it delivers them; past its buffer
        // libwebrtc closes the channel (the Ghost Chat lesson).
        if (n++ % 8 == 0) {
          while (await peer.buffered() > _highWater) {
            if (!peer.open) throw StateError('channel closed');
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        }
        await peer.send(piece);
      }
    });
    _queue = run.catchError((_) {});
    return run;
  }

  void _receive(Uint8List piece) {
    final Uint8List? bytes;
    try {
      bytes = _assembler.push(piece);
    } catch (_) {
      unawaited(close());
      return;
    }
    if (bytes == null) {
      _heard(request: false);
      return;
    }
    final LiveFrame frame;
    try {
      frame = decodeLiveFrame(bytes);
    } catch (_) {
      return;
    }
    final request = frame.type == 'get' || frame.type == 'file';
    _heard(request: request);
    if (frame.type == 'bye') {
      unawaited(close());
      return;
    }
    unawaited(
      _answers.handle(frame).catchError((Object error) async {
        final req = frame.header['req'];
        if (req == null) return;
        debugPrint('[HistoryLive] ${frame.type} failed: $error');
        await send({
          't': 'error',
          'req': req,
          'code': 'phone_error',
        }).catchError((_) {});
      }),
    );
  }

  void _heard({required bool request}) {
    _lost?.cancel();
    _lost = Timer(lostAfter, () => unawaited(close()));
    if (request) {
      _idle?.cancel();
      _idle = Timer(idleAfter, () => unawaited(close(sayBye: true)));
    }
  }

  Future<void> close({bool sayBye = false}) async {
    if (_closed) return;
    _closed = true;
    _lost?.cancel();
    _idle?.cancel();
    if (sayBye && open) await send({'t': 'bye'}).catchError((_) {});
    _assembler.clear();
    final peer = _peer;
    _peer = null;
    await peer?.dispose();
    onClosed();
  }
}
