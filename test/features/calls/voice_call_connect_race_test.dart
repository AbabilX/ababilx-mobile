import 'dart:async';

import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/call_harness.dart';

/// The caller offers the moment it hears "accepted", and the server keeps
/// nothing for a socket that is not there: an accept that overtakes the
/// callee's socket loses the offer.
void main() {
  group('answering from the background', () {
    callTest('the socket is up before the server hears the accept', (h) async {
      await h.event('call.incoming', 'A');
      h.ws.connectGate = Completer<void>();
      unawaited(h.calls.acceptIncoming('A'));
      await h.settle();
      expect(h.state.phase, VoiceCallPhase.connecting);
      expect(h.repo.actions, isNot(contains('accept:A')));

      h.ws.connectGate!.complete();
      await h.settle();
      expect(h.repo.actions, contains('accept:A'));
    });

    callTest('a socket that will not open cannot hold the answer', (h) async {
      await h.event('call.incoming', 'A');
      h.ws.connectGate = Completer<void>();
      unawaited(h.calls.acceptIncoming('A'));
      await h.wait(kTestRetryDelay * 2);
      expect(h.repo.actions, contains('accept:A'));
      h.ws.connectGate!.complete();
      await h.settle();
    });

    callTest('a decline while the socket opens sends no accept', (h) async {
      await h.event('call.incoming', 'A');
      h.ws.connectGate = Completer<void>();
      unawaited(h.calls.acceptIncoming('A'));
      await h.settle();
      await h.event('call.cancelled', 'A', status: 'cancelled');
      h.ws.connectGate!.complete();
      await h.settle();
      expect(h.repo.actions, isNot(contains('accept:A')));
    });

    callTest('hanging up while the socket opens sends no accept', (h) async {
      await h.event('call.incoming', 'A');
      h.ws.connectGate = Completer<void>();
      unawaited(h.calls.acceptIncoming('A'));
      await h.settle();
      await h.calls.hangUp();
      h.ws.connectGate!.complete();
      await h.settle();
      expect(h.repo.actions, isNot(contains('accept:A')));
      expect(h.engines, isEmpty);
    });

    callTest('a socket already up adds no wait', (h) async {
      await h.event('call.incoming', 'A');
      await h.calls.acceptIncoming('A');
      await h.settle();
      expect(h.repo.actions, contains('accept:A'));
      expect(h.engines, hasLength(1));
    });
  });

  group('a caller whose offer got no answer', () {
    final placed = VoiceCallState(
      currentUserId: 'peer',
      phase: VoiceCallPhase.outgoingRinging,
      call: testCall('A'),
    );

    Future<FakeEngine> accepted(CallHarness h) async {
      await h.event('call.accepted', 'A', status: 'accepted');
      await h.settle();
      return h.engines.single;
    }

    callTest('offers again, more than once', (h) async {
      final engine = await accepted(h);
      expect(engine.offers, 1);
      await h.wait(kTestRetryDelay * 5);
      expect(engine.offerRetries, 3);
    }, initial: placed);

    callTest('stops when the answer lands', (h) async {
      final engine = await accepted(h);
      engine.answered = true;
      await h.wait(kTestRetryDelay * 5);
      expect(engine.offerRetries, 0);
    }, initial: placed);

    callTest('stops when the media connects', (h) async {
      final engine = await accepted(h);
      engine.connected();
      await h.settle();
      await h.wait(kTestRetryDelay * 5);
      expect(engine.offerRetries, 0);
    }, initial: placed);

    callTest('stops when the call ends', (h) async {
      final engine = await accepted(h);
      await h.event('call.ended', 'A', status: 'ended');
      await h.wait(kTestRetryDelay * 5);
      expect(engine.offerRetries, 0);
    }, initial: placed);
  });

  test('the real schedule fits inside the connect watchdog', () {
    final total = VoiceCallNotifier.defaultOfferRetryDelays.fold(
      Duration.zero,
      (sum, delay) => sum + delay,
    );
    expect(VoiceCallNotifier.defaultOfferRetryDelays.first.inSeconds, 2);
    expect(VoiceCallNotifier.defaultOfferRetryDelays.length, greaterThan(1));
    expect(total, lessThan(const Duration(seconds: 35)));
  });
}
