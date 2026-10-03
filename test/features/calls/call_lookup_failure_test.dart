import 'dart:async';

import 'package:ababilx/features/calls/data/models/voice_call_session.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/call_harness.dart';

/// A request that failed says nothing about the call. Every lookup failure
/// used to end the ringing surface — on a phone that had just woken up, with
/// its radio asleep and its token expired, that was the common case.
void main() {
  callTest('recovery that cannot reach the server keeps the ring and retries', (
    h,
  ) async {
    h.nativeCalls = [
      {'id': 'B', 'isAccepted': false},
    ];
    h.repo.getErrors['B'] = [offline()];

    await h.calls.syncFromNativeIncoming();
    expect(h.state.phase, VoiceCallPhase.idle);
    expect(h.nativeEnded, isNot(contains('B')));

    await h.wait(kTestRetryDelay * 3);

    expect(h.repo.lookups, ['B', 'B']);
    expect(h.state.phase, VoiceCallPhase.incomingRinging);
    expect(h.state.call?.id, 'B');
    expect(h.nativeEnded, isNot(contains('B')));
  });

  callTest('the retries are bounded, and the surface outlives them', (h) async {
    h.nativeCalls = [
      {'id': 'B', 'isAccepted': false},
    ];
    h.repo.getErrors['B'] = List.generate(20, (_) => httpError(503));

    await h.calls.syncFromNativeIncoming();
    await h.wait(kTestRetryDelay * 12);

    // The first ask, then one per configured delay — and no more.
    expect(h.repo.lookups, hasLength(4));
    expect(h.nativeEnded, isNot(contains('B')));
    expect(h.state.phase, VoiceCallPhase.idle);
  });

  callTest('a call the server does not know ends its surface for good', (
    h,
  ) async {
    h.nativeCalls = [
      {'id': 'B', 'isAccepted': false},
    ];
    h.repo.getErrors['B'] = [httpError(404)];

    await h.calls.syncFromNativeIncoming();
    await h.wait(kTestRetryDelay * 3);

    expect(h.nativeEnded, contains('B'));
    expect(h.repo.lookups, ['B']);

    // Remembered: a replayed ring for it is not shown again.
    h.nativeCalls = [];
    await h.event('call.incoming', 'B');
    expect(h.state.phase, VoiceCallPhase.idle);
  });

  callTest('an Accept whose lookup fails in transit is not thrown away', (
    h,
  ) async {
    h.repo.getErrors['B'] = [offline()];

    await h.calls.acceptIncoming('B');
    expect(h.nativeEnded, isNot(contains('B')));
    expect(h.repo.actions, isEmpty);

    await h.wait(kTestRetryDelay * 3);

    expect(h.repo.actions, ['accept:B']);
    expect(h.state.phase, VoiceCallPhase.connecting);
    expect(h.calls.debugEngineCallId, 'B');
    expect(h.nativeEnded, isNot(contains('B')));
  });

  callTest('an Accept is not answered long after the press', (h) async {
    h.repo.getErrors['B'] = List.generate(20, (_) => offline());

    await h.calls.acceptIncoming('B');
    await h.wait(kTestRetryDelay * 12);

    // The press, then two re-asks. The surface stays; nothing was accepted.
    expect(h.repo.lookups, hasLength(3));
    expect(h.repo.actions, isEmpty);
    expect(h.nativeEnded, isNot(contains('B')));
    expect(h.state.phase, VoiceCallPhase.idle);
  });

  callTest('a 409 on accept is reconciled into the call, not a failure', (
    h,
  ) async {
    await h.event('call.incoming', 'B');
    h.repo.actionErrors['accept:B'] = [
      httpError(409, apiError: 'voice_call_state_conflict'),
    ];
    h.repo.rows['B'] = testSession('B', status: 'accepted');

    await h.calls.acceptIncoming('B');

    expect(h.state.phase, VoiceCallPhase.connecting);
    expect(h.calls.debugEngineCallId, 'B');
    expect(h.repo.actions, isNot(contains('fail:B')));
  });

  callTest('a 409 because another device answered ends quietly', (h) async {
    await h.event('call.incoming', 'B');
    h.repo.actionErrors['accept:B'] = [httpError(409)];
    h.repo.rows['B'] = testSession('B', status: 'accepted', canControl: false);

    await h.calls.acceptIncoming('B');

    expect(h.state.active, isFalse);
    expect(h.engines, isEmpty);
    expect(h.repo.actions, isNot(contains('fail:B')));
  });

  callTest('recovery never touches a call whose media is live', (h) async {
    final engine = await h.connect('A');
    // State loses the call while its engine runs on: the fault this guards.
    h.calls.force(const VoiceCallState(currentUserId: 'me'));
    h.nativeCalls = [
      {'id': 'A', 'isAccepted': true},
    ];

    await h.calls.syncFromNativeIncoming();

    expect(h.state.phase, VoiceCallPhase.idle);
    expect(engine.disposed, isFalse);
    expect(h.calls.debugEngineCallId, 'A');
    expect(h.nativeEnded, isNot(contains('A')));
    expect(h.logged('STALE_CALL_OPERATION', 'reason=engine_live'), isTrue);
  });

  callTest('a recovery answer that arrives late cannot replace the live call', (
    h,
  ) async {
    h.nativeCalls = [
      {'id': 'X', 'isAccepted': false},
    ];
    final lookup = h.repo.heldLookups['X'] = Completer<VoiceCallSession>();
    final recovering = h.calls.syncFromNativeIncoming();
    await h.settle();

    final engine = await h.connect('Y');
    lookup.complete(testSession('X'));
    await recovering;
    await h.settle();

    expect(h.state.phase, VoiceCallPhase.connected);
    expect(h.state.call?.id, 'Y');
    expect(engine.disposed, isFalse);
    expect(h.logged('STALE_CALL_OPERATION', 'reason=late_lookup'), isTrue);
  });
}
