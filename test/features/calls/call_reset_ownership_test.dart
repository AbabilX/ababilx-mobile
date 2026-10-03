import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/call_harness.dart';

/// "The call screen disappeared and I could still hear them."
///
/// A fixed delay after ANY call ended, a timer wrote idle — whatever was in
/// state by then. A call that rang or was answered inside that window lost
/// its screen, its return bar and its ongoing notification while its media
/// kept running. These pin the rule that replaced it: the reset belongs to
/// the call it was armed for, and is checked when it fires.
void main() {
  callTest('A ends, B is answered inside the window: B outlives A\'s timer', (
    h,
  ) async {
    await h.connect('A');
    await h.event('call.ended', 'A', status: 'ended');
    expect(h.state.phase, VoiceCallPhase.ended);
    expect(h.calls.debugResetPending, isTrue);

    final engine = await h.connect('B');
    expect(h.state.phase, VoiceCallPhase.connected);

    await h.pastReset();

    expect(h.state.phase, VoiceCallPhase.connected);
    expect(h.state.call?.id, 'B');
    expect(h.calls.debugEngineCallId, 'B');
    expect(engine.disposed, isFalse);
    expect(h.logged('RESET_CANCELLED', 'callId=B'), isTrue);
    expect(h.logged('RESET_FIRED'), isFalse);
  });

  callTest('A ends, B only rings inside the window: the ring stays up', (
    h,
  ) async {
    await h.connect('A');
    await h.event('call.ended', 'A', status: 'ended');
    expect(h.calls.debugResetPending, isTrue);

    await h.event('call.incoming', 'B');
    await h.pastReset();

    expect(h.state.phase, VoiceCallPhase.incomingRinging);
    expect(h.state.call?.id, 'B');
    expect(h.nativeEnded, isNot(contains('B')));
  });

  callTest('B arrives after the reset: nothing of A is left to reach it', (
    h,
  ) async {
    await h.connect('A');
    await h.event('call.ended', 'A', status: 'ended');
    await h.pastReset();
    expect(h.state.phase, VoiceCallPhase.idle);
    expect(h.logged('RESET_FIRED', 'callId=A'), isTrue);

    final engine = await h.connect('B');
    await h.pastReset();

    expect(h.state.phase, VoiceCallPhase.connected);
    expect(h.calls.debugEngineCallId, 'B');
    expect(engine.disposed, isFalse);
  });

  callTest('a stale timer that does fire is refused, not obeyed', (h) async {
    await h.connect('A');
    await h.event('call.ended', 'A', status: 'ended');
    expect(h.calls.debugResetPending, isTrue);

    // B takes the state without anything cancelling A's timer — the one
    // thing no production path does, and exactly what cancelling alone
    // cannot protect against.
    h.calls.force(
      VoiceCallState(
        phase: VoiceCallPhase.connected,
        currentUserId: 'me',
        call: testCall('B', status: 'accepted'),
        connectedAt: DateTime.now(),
      ),
    );
    await h.pastReset();

    expect(h.state.phase, VoiceCallPhase.connected);
    expect(h.state.call?.id, 'B');
    expect(h.logged('RESET_IGNORED', 'reason=stale_call'), isTrue);
    expect(h.logged('RESET_FIRED'), isFalse);
  });

  callTest('idle is never written while a call is live', (h) async {
    final engine = await h.connect('A');

    h.calls.reset();

    expect(h.state.phase, VoiceCallPhase.connected);
    expect(engine.disposed, isFalse);
    expect(h.logged('RESET_IGNORED', 'reason=call_active'), isTrue);
  });

  callTest('idle is never written while media exists, whatever state says', (
    h,
  ) async {
    final engine = await h.connect('A');

    // State loses the call; the engine is still there.
    h.calls.force(
      const VoiceCallState(phase: VoiceCallPhase.ended, currentUserId: 'me'),
    );
    h.calls.reset();

    expect(h.state.phase, VoiceCallPhase.ended);
    expect(h.calls.debugEngineCallId, 'A');
    expect(engine.disposed, isFalse);
    expect(h.logged('RESET_IGNORED', 'reason=engine_live'), isTrue);
  });

  callTest('a finished call still returns to idle on its own', (h) async {
    final engine = await h.connect('A');
    await h.calls.hangUp();
    expect(h.state.phase, VoiceCallPhase.ended);
    expect(engine.disposed, isTrue);
    expect(h.calls.debugEngineCallId, isNull);

    await h.pastReset();

    expect(h.state.phase, VoiceCallPhase.idle);
    expect(h.repo.actions, contains('end:A'));
  });
}
