import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/voice_call_heartbeat.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceCall _call(String status) => VoiceCall(
  id: 'call-1',
  teamId: '',
  conversationId: 'conv-1',
  callerId: 'a',
  calleeId: 'b',
  status: status,
  callerName: 'A',
  calleeName: 'B',
  expiresAt: DateTime.utc(2026, 1, 1),
  createdAt: DateTime.utc(2026, 1, 1),
);

DioException _http(int status) => DioException(
  requestOptions: RequestOptions(path: '/actions'),
  response: Response(
    requestOptions: RequestOptions(path: '/actions'),
    statusCode: status,
  ),
);

void main() {
  const tick = Duration(milliseconds: 10);

  test('beats until stopped', () async {
    var beats = 0;
    final heartbeat = VoiceCallHeartbeat(
      send: (_) async {
        beats++;
        return _call('accepted');
      },
      onEndedRemotely: (_) => fail('call is live'),
      interval: tick,
    );
    heartbeat.start('call-1');
    await Future<void>.delayed(tick * 5);
    heartbeat.stop();
    final settled = beats;
    await Future<void>.delayed(tick * 5);
    expect(beats, greaterThan(1));
    expect(beats, settled, reason: 'stop() ends the beats');
  });

  test('a terminal row reports the call as ended and stops beating', () async {
    var beats = 0;
    VoiceCall? ended;
    final heartbeat = VoiceCallHeartbeat(
      send: (_) async {
        beats++;
        return _call('failed');
      },
      onEndedRemotely: (call) => ended = call,
      interval: tick,
    );
    heartbeat.start('call-1');
    await Future<void>.delayed(tick * 5);
    expect(ended?.status, 'failed');
    expect(beats, 1, reason: 'no beats after the server says the call is over');
  });

  test('a server that does not know the action is never asked again', () async {
    var beats = 0;
    final heartbeat = VoiceCallHeartbeat(
      send: (_) async {
        beats++;
        throw _http(400);
      },
      onEndedRemotely: (_) => fail('400 is not a call ending'),
      interval: tick,
    );
    heartbeat.start('call-1');
    await Future<void>.delayed(tick * 4);
    expect(beats, 1);
    // Even a fresh call gets no beats: the server cannot answer them.
    heartbeat.start('call-2');
    await Future<void>.delayed(tick * 4);
    expect(beats, 1);
  });

  test('keeps beating through the outage it exists to survive', () async {
    var beats = 0;
    final heartbeat = VoiceCallHeartbeat(
      send: (_) async {
        beats++;
        throw _http(503);
      },
      onEndedRemotely: (_) => fail('a 5xx is not a call ending'),
      interval: tick,
    );
    heartbeat.start('call-1');
    await Future<void>.delayed(tick * 5);
    heartbeat.stop();
    expect(beats, greaterThan(1));
  });
}
