import 'package:ababilx/features/calls/webrtc/voice_audio_cap.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds one poll every 2 s and hands back what the rule asked for.
class _Call {
  final cap = VoiceAudioCap();
  int now = 0;

  VoiceCapAction poll({
    double? loss = 0,
    double? rtt = 50,
    String? path = 'p1',
    bool video = false,
    bool live = true,
  }) {
    now += 2000;
    return cap.update(
      remoteLossPercent: loss,
      rttMs: rtt,
      pathKey: path,
      videoSending: video,
      live: live,
      nowMs: now,
    );
  }

  List<VoiceCapAction> polls(int count, {double? loss = 0, double? rtt = 50}) =>
      [for (var i = 0; i < count; i++) poll(loss: loss, rtt: rtt)];

  void congest() {
    polls(2);
    final actions = polls(3, loss: 12, rtt: 200);
    expect(actions, contains(VoiceCapAction.cap));
    expect(cap.capped, isTrue);
  }
}

void main() {
  test('production builds leave the voice rate alone', () {
    expect(kVoiceAudioCapEnabled, isFalse);
  });

  test('a healthy call is never touched', () {
    final call = _Call();
    expect(call.polls(200).toSet(), {VoiceCapAction.none});
  });

  test('loss with a growing queue is congestion: the voice steps down', () {
    final call = _Call();
    call.polls(3);
    expect(call.poll(loss: 12, rtt: 200), VoiceCapAction.none); // one reading
    expect(call.poll(loss: 12, rtt: 200), VoiceCapAction.cap);
    expect(call.poll(loss: 12, rtt: 200), VoiceCapAction.none); // only once
  });

  test('loss on a flat path is not: a lower rate would only sound worse', () {
    final call = _Call();
    call.polls(3);
    expect(call.polls(50, loss: 25, rtt: 55).toSet(), {VoiceCapAction.none});
  });

  test('a slow path with no loss is left alone', () {
    final call = _Call();
    call.polls(3);
    expect(call.polls(50, rtt: 900).toSet(), {VoiceCapAction.none});
  });

  test('a stable high delay is judged from its own floor', () {
    final call = _Call();
    expect(call.polls(50, loss: 10, rtt: 700).toSet(), {VoiceCapAction.none});
  });

  test('unmeasured figures decide nothing', () {
    final call = _Call();
    call.polls(3);
    expect(call.polls(10, loss: null, rtt: 500).toSet(), {VoiceCapAction.none});
    expect(call.polls(10, loss: 20, rtt: null).toSet(), {VoiceCapAction.none});
  });

  test('the cap lifts only after the link stayed calm for the hold', () {
    final call = _Call();
    call.congest();
    final calm = call.polls(VoiceAudioCap.firstHoldMs ~/ 2000 + 1);
    expect(calm.last, VoiceCapAction.lift);
    expect(calm.where((a) => a == VoiceCapAction.lift), hasLength(1));
    expect(call.cap.capped, isFalse);
  });

  test('a bad reading during the hold starts the wait again', () {
    final call = _Call();
    call.congest();
    call.polls(VoiceAudioCap.firstHoldMs ~/ 2000 - 2);
    call.poll(loss: 0, rtt: 200);
    expect(call.polls(VoiceAudioCap.firstHoldMs ~/ 2000 - 2).toSet(), {
      VoiceCapAction.none,
    });
  });

  test('stepping down again soon after doubles the next hold', () {
    final call = _Call();
    call.congest();
    call.polls(VoiceAudioCap.firstHoldMs ~/ 2000 + 1);
    expect(call.cap.capped, isFalse);
    call.congest();
    expect(call.polls(VoiceAudioCap.firstHoldMs ~/ 2000 + 1).toSet(), {
      VoiceCapAction.none,
    });
    expect(
      call.polls(VoiceAudioCap.firstHoldMs ~/ 2000),
      contains(VoiceCapAction.lift),
    );
  });

  test('the hold never grows past its maximum', () {
    final call = _Call();
    for (var i = 0; i < 8; i++) {
      call.congest();
      final lifted = call.polls(VoiceAudioCap.maxHoldMs ~/ 2000 + 1);
      expect(lifted, contains(VoiceCapAction.lift), reason: 'round $i');
    }
  });

  test('a calm spell after lifting resets the hold', () {
    final call = _Call();
    call.congest();
    call.polls(VoiceAudioCap.firstHoldMs ~/ 2000 + 1);
    call.polls(VoiceAudioCap.calmMs ~/ 2000 + 1);
    call.congest();
    expect(
      call.polls(VoiceAudioCap.firstHoldMs ~/ 2000 + 1),
      contains(VoiceCapAction.lift),
    );
  });

  test('a new path is a new link: the cap goes and its floor is relearned', () {
    final call = _Call();
    call.congest();
    expect(call.poll(rtt: 400, path: 'p2'), VoiceCapAction.lift);
    expect(call.cap.capped, isFalse);
    // 400 is the new floor, so it does not read as a queue.
    expect(call.poll(loss: 10, rtt: 410, path: 'p2'), VoiceCapAction.none);
    expect(call.poll(loss: 10, rtt: 410, path: 'p2'), VoiceCapAction.none);
  });

  test('a dead path decides nothing and breaks a run of readings', () {
    final call = _Call();
    call.polls(3);
    call.poll(loss: 12, rtt: 200);
    expect(call.poll(loss: 12, rtt: 200, live: false), VoiceCapAction.none);
    expect(call.poll(loss: 12, rtt: 200), VoiceCapAction.none);
    expect(call.poll(loss: 12, rtt: 200), VoiceCapAction.cap);
  });

  test('with a picture going out, the camera hold owns the link', () {
    final call = _Call();
    call.polls(3);
    for (var i = 0; i < 20; i++) {
      expect(call.poll(loss: 12, rtt: 200, video: true), VoiceCapAction.none);
    }
    expect(call.cap.capped, isFalse);
  });

  test('a refused change is forgotten, so it is tried again', () {
    final call = _Call();
    call.congest();
    call.cap.undo(VoiceCapAction.cap);
    expect(call.cap.capped, isFalse);
    expect(call.polls(2, loss: 12, rtt: 200), contains(VoiceCapAction.cap));
    call.cap.undo(VoiceCapAction.none);
    expect(call.cap.capped, isTrue);
  });

  test('lifting goes back to the rate the call began with, not above', () {
    expect(kVoiceCappedBps, lessThan(kVoiceFullBps));
    expect(kVoiceFullBps, 32000);
  });
}
