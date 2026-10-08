import 'package:ababilx/features/calls/network/call_network_quality.dart';
import 'package:ababilx/features/calls/webrtc/voice_video_hold.dart';
import 'package:flutter_test/flutter_test.dart';

const _good = CallNetworkLevel.good;
const _weak = CallNetworkLevel.weak;

/// Feeds one reading every two seconds, as the engine's stats poll does.
class _Run {
  final hold = VoiceVideoHold();
  int now = 0;

  VideoHoldAction tick({
    int? est = 500000,
    int? video = 300000,
    CallNetworkLevel path = _good,
    bool camera = true,
  }) {
    now += 2000;
    return hold.update(
      cameraOn: camera,
      availableBps: est,
      videoBps: video,
      path: path,
      nowMs: now,
    );
  }

  /// Ticks until [seconds] have passed; every action seen on the way.
  List<VideoHoldAction> run(
    int seconds, {
    int? est = 500000,
    int? video = 300000,
    CallNetworkLevel path = _good,
  }) => [
    for (var i = 0; i < seconds ~/ 2; i++)
      tick(est: est, video: video, path: path),
  ].where((a) => a != VideoHoldAction.none).toList();

  /// Past the settle time on a healthy link, then starved until held.
  void starveUntilHeld() {
    run(14);
    expect(run(10, est: 60000, video: 30000), [VideoHoldAction.hold]);
  }
}

void main() {
  test('a healthy video call is never touched', () {
    expect(_Run().run(600), isEmpty);
  });

  test('a starved link holds the camera after eight seconds, not before', () {
    final r = _Run()..run(14);
    expect(r.run(6, est: 60000, video: 30000), isEmpty);
    expect(r.hold.held, isFalse);
    expect(r.run(4, est: 60000, video: 30000), [VideoHoldAction.hold]);
    expect(r.hold.held, isTrue);
  });

  test('one better reading starts the count again', () {
    final r = _Run()..run(14);
    r.run(6, est: 60000, video: 30000);
    r.tick();
    expect(r.run(6, est: 60000, video: 30000), isEmpty);
  });

  test('a camera that has just started is given time to ramp up', () {
    final r = _Run();
    expect(r.run(10, est: 60000, video: 30000), isEmpty);
    expect(r.run(10, est: 400000), isEmpty);
  });

  test('a low estimate alone is not enough', () {
    final r = _Run()..run(14);
    // The picture is taking almost nothing: stopping it frees nothing.
    expect(r.run(60, est: 60000, video: 5000), isEmpty);
    // No estimate, or no rate yet, is no evidence.
    expect(r.run(60, est: null, video: 30000), isEmpty);
    expect(r.run(60, est: 60000, video: null), isEmpty);
  });

  test('the picture returns after ten good seconds, not on a weak path', () {
    final r = _Run()..starveUntilHeld();
    expect(r.run(60, est: 60000, video: 0, path: _weak), isEmpty);
    expect(r.run(8, est: 60000, video: 0), isEmpty);
    r.tick(path: _weak);
    expect(r.run(8, est: 60000, video: 0), isEmpty);
    expect(r.run(4, est: 60000, video: 0), [VideoHoldAction.resume]);
    expect(r.hold.held, isFalse);
  });

  test('each try that fails doubles the wait before the next', () {
    final r = _Run()..starveUntilHeld();
    int secondsUntilResume() {
      var seconds = 0;
      while (r.tick(est: 60000, video: 0) != VideoHoldAction.resume) {
        seconds += 2;
        expect(seconds, lessThan(400));
      }
      return seconds;
    }

    final waits = <int>[];
    for (var i = 0; i < 6; i++) {
      waits.add(secondsUntilResume());
      // Back on a link that still cannot carry it: held again.
      while (r.tick(est: 60000, video: 30000) != VideoHoldAction.hold) {}
    }
    expect(waits, [10, 20, 40, 80, 120, 120]);
  });

  test('a picture that lasts a minute resets the wait', () {
    final r = _Run()..starveUntilHeld();
    expect(r.run(12, est: 60000, video: 0), [VideoHoldAction.resume]);
    r.run(70);
    expect(r.run(10, est: 60000, video: 30000), [VideoHoldAction.hold]);
    expect(r.run(10, est: 60000, video: 0), isEmpty);
    expect(r.run(2, est: 60000, video: 0), [VideoHoldAction.resume]);
  });

  test('turning the camera off forgets everything', () {
    final r = _Run()..starveUntilHeld();
    r.tick(camera: false);
    expect(r.hold.held, isFalse);
    // On again: a fresh camera, judged from the start.
    expect(r.run(12, est: 60000, video: 30000), isEmpty);
  });

  test('a dropped path breaks a stretch on both sides', () {
    final r = _Run()..run(14);
    r.run(6, est: 60000, video: 30000);
    r.hold.interrupt();
    expect(r.run(18, est: 60000, video: 30000), isEmpty);
    expect(r.run(4, est: 60000, video: 30000), [VideoHoldAction.hold]);
    r.run(8, est: 60000, video: 0);
    r.hold.interrupt();
    expect(r.hold.held, isTrue);
    expect(r.run(8, est: 60000, video: 0), isEmpty);
  });

  test('a change the sender refused is asked again', () {
    final r = _Run()..starveUntilHeld();
    r.hold.undo(VideoHoldAction.hold);
    expect(r.hold.held, isFalse);
    expect(r.run(30, est: 60000, video: 30000), [VideoHoldAction.hold]);
    expect(r.run(12, est: 60000, video: 0), [VideoHoldAction.resume]);
    r.hold.undo(VideoHoldAction.resume);
    expect(r.hold.held, isTrue);
    expect(r.run(60, est: 60000, video: 0), [VideoHoldAction.resume]);
  });
}
