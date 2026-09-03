import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/voice_call_ringable.dart';
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

  test('a live ringing call may raise a ringing surface', () {
    expect(isVoiceCallRingable(call('ringing'), now: now), isTrue);
  });

  // The lock-screen surface can be answered by hand long after the caller gave
  // up, so every terminal status has to be refused — that Accept arrives as an
  // ordinary CallKit event and is otherwise indistinguishable from a real one.
  for (final status in ['cancelled', 'declined', 'ended', 'missed', 'failed']) {
    test('a $status call does not', () {
      expect(isVoiceCallRingable(call(status), now: now), isFalse);
    });
  }

  test('a call already accepted elsewhere does not', () {
    expect(isVoiceCallRingable(call('accepted'), now: now), isFalse);
  });

  test('a ringing call that has rung out does not', () {
    final expired = call(
      'ringing',
      expiresAt: now.subtract(const Duration(seconds: 1)),
    );
    expect(isVoiceCallRingable(expired, now: now), isFalse);
  });
}
