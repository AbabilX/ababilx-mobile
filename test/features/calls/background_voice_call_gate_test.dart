import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/native/background_voice_call_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 3, 12);

  VoiceCall call(String status, {DateTime? expiresAt}) => VoiceCall(
    id: 'call-1',
    teamId: '',
    conversationId: 'conversation-1',
    callerId: 'caller-1',
    calleeId: 'callee-1',
    status: status,
    callerName: 'Caller',
    calleeName: 'Callee',
    expiresAt: expiresAt ?? now.add(const Duration(seconds: 30)),
    createdAt: now,
  );

  Map<String, dynamic> push({DateTime? expiresAt}) => {
    'call_id': 'call-1',
    'expires_at': (expiresAt ?? now.add(const Duration(seconds: 30)))
        .toIso8601String(),
  };

  test('presents only an authoritative ringing call', () async {
    final result = await BackgroundVoiceCallGate.shouldPresent(
      push(),
      now: now,
      endedLookup: (_) async => false,
      lookup: (_) async => call('ringing'),
    );
    expect(result, isTrue);
  });

  for (final status in ['accepted', 'cancelled', 'declined', 'ended']) {
    test('rejects a server call in $status state', () async {
      final result = await BackgroundVoiceCallGate.shouldPresent(
        push(),
        now: now,
        endedLookup: (_) async => false,
        lookup: (_) async => call(status),
      );
      expect(result, isFalse);
    });
  }

  test('rejects a terminal push observed before incoming', () async {
    final result = await BackgroundVoiceCallGate.shouldPresent(
      push(),
      now: now,
      endedLookup: (_) async => true,
      lookup: (_) async => call('ringing'),
    );
    expect(result, isFalse);
  });

  test('rejects an expired push without querying the server', () async {
    var queried = false;
    final result = await BackgroundVoiceCallGate.shouldPresent(
      push(expiresAt: now.subtract(const Duration(seconds: 1))),
      now: now,
      endedLookup: (_) async => false,
      lookup: (_) async {
        queried = true;
        return call('ringing');
      },
    );
    expect(result, isFalse);
    expect(queried, isFalse);
  });

  test('fails closed when authoritative lookup fails', () async {
    final result = await BackgroundVoiceCallGate.shouldPresent(
      push(),
      now: now,
      endedLookup: (_) async => false,
      lookup: (_) async => throw Exception('offline'),
    );
    expect(result, isFalse);
  });
}
