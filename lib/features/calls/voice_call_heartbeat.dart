import 'dart:async';

import 'package:dio/dio.dart';

import 'data/models/voice_call.dart';
import 'voice_call_log.dart';

/// Tells the server this device is still on the call.
///
/// An accepted call used to have exactly one way to end: a client saying so.
/// The two commonest ways a call dies — the network going away, and the app
/// being killed — are precisely the two that stop that message from ever being
/// sent, so the row stayed `accepted` forever and both people were refused
/// every later call as "busy". A beat the server can miss is the only signal
/// that survives either failure.
///
/// It is also the recovery channel in the other direction: the response
/// carries the row, so a device that was offline long enough for the server to
/// end its call finds out on the first beat that gets through, rather than
/// sitting in a call nobody else is in.
class VoiceCallHeartbeat {
  VoiceCallHeartbeat({
    required this.send,
    required this.onEndedRemotely,
    this.interval = const Duration(seconds: 20),
  });

  /// POSTs one beat and returns the server's view of the call.
  final Future<VoiceCall> Function(String callId) send;

  /// The server no longer has this call live.
  final void Function(VoiceCall call) onEndedRemotely;

  final Duration interval;

  Timer? _timer;
  String? _callId;

  /// A server that predates the heartbeat action answers 400 once, and then
  /// there is nothing to gain by asking again for the rest of the session.
  bool _unsupported = false;

  void start(String callId) {
    if (_unsupported) return;
    _timer?.cancel();
    _callId = callId;
    _timer = Timer.periodic(interval, (_) => unawaited(_beat(callId)));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _callId = null;
  }

  Future<void> _beat(String callId) async {
    if (_callId != callId) return;
    try {
      final call = await send(callId);
      if (_callId != callId) return;
      if (call.isTerminal) {
        voiceCallLog('heartbeat.ended', callId: callId, reason: call.status);
        stop();
        onEndedRemotely(call);
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400) {
        // Old server: the action is not understood. Stop asking.
        _unsupported = true;
        voiceCallLog('heartbeat.unsupported', callId: callId);
        stop();
        return;
      }
      if (status == 404) {
        stop();
        return;
      }
      // Anything else — a timeout, a 5xx, no network — is exactly the
      // condition a heartbeat exists to ride out. Keep beating.
      voiceCallLog('heartbeat.retry', callId: callId, reason: '$status');
    } catch (error) {
      voiceCallLog('heartbeat.error', callId: callId, reason: error.toString());
    }
  }
}
