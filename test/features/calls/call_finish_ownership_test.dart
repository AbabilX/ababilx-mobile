import 'dart:async';

import 'package:ababilx/features/calls/data/models/voice_call_session.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/call_harness.dart';

/// Work that began for call X must not mutate or dispose anything that
/// belongs to call Y: not its state, its engine, its timers, its queued
/// signals or the operation counter its own async steps check.
void main() {
  void expectUntouched(CallHarness h, FakeEngine engine, String id) {
    expect(h.state.phase, VoiceCallPhase.connected);
    expect(h.state.call?.id, id);
    expect(h.calls.debugEngineCallId, id);
    expect(engine.disposed, isFalse);
  }

  callTest('A\'s teardown finishing after B rang leaves B ringing', (h) async {
    final engineA = await h.connect('A');
    // A's teardown stays in flight: its engine has not finished closing.
    engineA.disposeGate = Completer<void>();
    await h.event('call.ended', 'A', status: 'ended');
    expect(h.state.phase, VoiceCallPhase.ended);
    expect(engineA.disposed, isFalse);

    await h.event('call.incoming', 'B');
    expect(h.state.phase, VoiceCallPhase.incomingRinging);

    engineA.disposeGate!.complete();
    await h.settle();

    expect(engineA.disposed, isTrue);
    expect(h.state.phase, VoiceCallPhase.incomingRinging);
    expect(h.state.call?.id, 'B');
    expect(h.calls.debugResetPending, isFalse);
    expect(h.logged('STALE_CALL_OPERATION', 'finishLocal.tail'), isTrue);

    await h.pastReset();
    expect(h.state.phase, VoiceCallPhase.incomingRinging);

    final engineB = await h.connect('B');
    expectUntouched(h, engineB, 'B');
  });

  callTest('a decline for stale X leaves live Y alone', (h) async {
    final engine = await h.connect('Y');
    final generation = h.calls.debugOperation;

    await h.calls.declineIncoming('X');
    await h.pastReset();

    expectUntouched(h, engine, 'Y');
    expect(h.calls.debugOperation, generation);
    expect(h.nativeEnded, contains('X'));
    expect(h.nativeEnded, isNot(contains('Y')));
    expect(h.repo.actions, contains('decline:X'));
    expect(h.repo.actions.where((a) => a.endsWith(':Y')), ['accept:Y']);
    expect(h.logged('STALE_CALL_OPERATION', 'targetCallId=X'), isTrue);
  });

  callTest('an Accept for X while Y is live is refused before anything moves', (
    h,
  ) async {
    final engine = await h.connect('Y');
    final generation = h.calls.debugOperation;

    await h.calls.acceptIncoming('X');
    await h.settle();

    expectUntouched(h, engine, 'Y');
    expect(h.calls.debugOperation, generation);
    expect(h.engines, hasLength(1));
    expect(h.repo.lookups, isNot(contains('X')));
    expect(h.repo.actions, isNot(contains('accept:X')));
    expect(h.nativeEnded, contains('X'));
    expect(h.logged('STALE_CALL_OPERATION', 'operation=accept'), isTrue);
  });

  callTest('an Accept for a call that is over moves nothing', (h) async {
    await h.event('call.incoming', 'Y');
    h.repo.rows['X'] = testSession('X', status: 'cancelled');
    final generation = h.calls.debugOperation;

    await h.calls.acceptIncoming('X');

    expect(h.calls.debugOperation, generation);
    expect(h.state.phase, VoiceCallPhase.incomingRinging);
    expect(h.state.call?.id, 'Y');
    expect(h.nativeEnded, contains('X'));
    expect(h.repo.actions, isEmpty);
  });

  callTest('a late answer for A lands on nothing once B is the call', (
    h,
  ) async {
    await h.event('call.incoming', 'A');
    final accept = h.repo.held['accept:A'] = Completer<VoiceCallSession>();
    final accepting = h.calls.acceptIncoming('A');
    await h.settle();
    expect(h.state.phase, VoiceCallPhase.connecting);

    // A ends while its accept is still on the wire; B takes the phone.
    await h.event('call.ended', 'A', status: 'ended');
    final engine = await h.connect('B');

    accept.complete(testSession('A', status: 'accepted'));
    await accepting;
    await h.pastReset();

    expectUntouched(h, engine, 'B');
    expect(h.engines, hasLength(1));
    expect(h.repo.actions, contains('end:A'));
  });

  callTest('the same Accept twice answers once', (h) async {
    await h.event('call.incoming', 'B');
    final generation = h.calls.debugOperation;

    await Future.wait([
      h.calls.acceptIncoming('B'),
      h.calls.acceptIncoming('B'),
    ]);
    await h.calls.acceptIncoming('B');
    await h.settle();

    expect(h.repo.actions.where((a) => a == 'accept:B'), hasLength(1));
    expect(h.engines, hasLength(1));
    expect(h.calls.debugOperation, generation + 1);
    expect(h.state.phase, VoiceCallPhase.connecting);
    expect(h.engines.single.disposed, isFalse);
  });

  callTest('the same Accept twice from a cold start answers once', (h) async {
    h.repo.rows['B'] = testSession('B');

    await Future.wait([
      h.calls.acceptIncoming('B'),
      h.calls.acceptIncoming('B'),
    ]);
    await h.settle();

    expect(h.repo.actions.where((a) => a == 'accept:B'), hasLength(1));
    expect(h.engines, hasLength(1));
    expect(h.calls.debugEngineCallId, 'B');
  });

  callTest('a decline delivered again cannot reach the next call', (h) async {
    await h.event('call.incoming', 'A');
    await h.calls.declineIncoming('A');
    await h.calls.declineIncoming('A');
    expect(h.state.phase, VoiceCallPhase.ended);

    final engine = await h.connect('B');
    final generation = h.calls.debugOperation;
    await h.calls.declineIncoming('A');
    await h.pastReset();

    expectUntouched(h, engine, 'B');
    expect(h.calls.debugOperation, generation);
    expect(h.repo.actions, isNot(contains('decline:B')));
  });

  callTest('a call whose state was lost still closes its own engine', (
    h,
  ) async {
    final engine = await h.connect('A');
    // State loses the call while its engine lives: the fault this guards.
    h.calls.force(const VoiceCallState(currentUserId: 'me'));

    await h.calls.declineIncoming('A');

    expect(engine.disposed, isTrue);
    expect(h.calls.debugEngineCallId, isNull);
    expect(h.calls.debugHasEngine, isFalse);
  });
}
