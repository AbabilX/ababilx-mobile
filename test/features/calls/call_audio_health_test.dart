import 'package:ababilx/features/calls/diagnostics/call_audio_health.dart';
import 'package:ababilx/features/calls/diagnostics/call_audio_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Packets flowing, nothing wrong, every figure known.
CallAudioSample _ok({
  int? delta = 50,
  int total = 1000,
  double? loss = 0,
  double? jitter = 10,
  double? buffer = 60,
  double? concealment = 0,
  double? playout = 1,
  bool hasInbound = true,
  bool hasOutbound = true,
  int? transport,
}) => CallAudioSample(
  hasInbound: hasInbound,
  hasOutbound: hasOutbound,
  packetsReceived: hasInbound ? total : null,
  packetsReceivedDelta: delta,
  transportPacketsDelta: transport,
  lossPercent: loss,
  jitterMs: jitter,
  jitterBufferDelayMs: buffer,
  concealmentPercent: concealment,
  playoutShare: playout,
);

void main() {
  late CallAudioHealthTracker tracker;
  var now = 0;

  /// One poll, 2 s after the last.
  CallAudioHealthReport poll(
    CallAudioSample sample, {
    bool connected = true,
    bool iceConnected = true,
  }) {
    now += 2000;
    return tracker.add(
      sample,
      nowMs: now,
      connected: connected,
      iceConnected: iceConnected,
    );
  }

  /// Runs out the setup grace with a healthy call.
  void settle() {
    for (var i = 0; i < 4; i++) {
      poll(_ok());
    }
  }

  setUp(() {
    tracker = CallAudioHealthTracker();
    now = 0;
  });

  group('setup and reconnection never alarm', () {
    test('no audio yet during call setup is settling', () {
      final report = poll(_ok(hasInbound: false, delta: null));
      expect(report.status, CallAudioHealth.settling);
    });

    test('a call that is not connected is settling, whatever it reads', () {
      settle();
      final report = poll(_ok(delta: 0), connected: false);
      expect(report.status, CallAudioHealth.settling);
      expect(report.signals, isEmpty);
    });

    test('ICE down mid-call is settling and the stall count starts over', () {
      settle();
      poll(_ok(delta: 0));
      poll(_ok(delta: 0), iceConnected: false);
      for (var i = 0; i < 2; i++) {
        expect(poll(_ok(delta: 0)).status, CallAudioHealth.settling);
      }
    });

    test('after a reconnect there is a grace before a stall counts', () {
      settle();
      poll(_ok(delta: 0), connected: false);
      expect(poll(_ok(delta: 0)).status, CallAudioHealth.settling);
      expect(poll(_ok(delta: 0)).status, CallAudioHealth.settling);
      poll(_ok(delta: 0));
      expect(poll(_ok(delta: 0)).status, CallAudioHealth.packetStall);
    });
  });

  group('a stall', () {
    test('one empty interval is not a failure', () {
      settle();
      final report = poll(_ok(delta: 0));
      expect(report.status, CallAudioHealth.healthy);
      expect(report.signals, isNot(contains(CallAudioSignal.packetStall)));
    });

    test('two empty intervals in a row are', () {
      settle();
      poll(_ok(delta: 0));
      final report = poll(_ok(delta: 0));
      expect(report.status, CallAudioHealth.packetStall);
      expect(report.signals, contains(CallAudioSignal.packetStall));
      expect(report.stalledIntervals, 2);
    });

    test('packets coming back clear it', () {
      settle();
      poll(_ok(delta: 0));
      poll(_ok(delta: 0));
      final report = poll(_ok());
      expect(report.status, CallAudioHealth.healthy);
      expect(report.stalledIntervals, 0);
    });

    test('an unknown step (counter reset, new stream) is not an empty one', () {
      settle();
      poll(_ok(delta: 0));
      poll(_ok(delta: null));
      final report = poll(_ok(delta: 0));
      expect(report.status, CallAudioHealth.healthy);
      expect(report.stalledIntervals, 1);
    });

    test('a quiet interval during a loss report is a stall, not loss', () {
      settle();
      poll(_ok(delta: 0, loss: 40));
      expect(poll(_ok(delta: 0, loss: 40)).status, CallAudioHealth.packetStall);
    });
  });

  group('silence with the path alive', () {
    test('no voice packets but control traffic: the peer is not sending', () {
      settle();
      poll(_ok(delta: 0, transport: 3));
      final report = poll(_ok(delta: 0, transport: 2));
      expect(report.status, CallAudioHealth.inboundSilent);
      expect(report.signals, contains(CallAudioSignal.peerSilent));
      expect(report.signals, isNot(contains(CallAudioSignal.packetStall)));
    });

    test('control traffic comes in bursts: one sighting holds the verdict', () {
      settle();
      poll(_ok(delta: 0, transport: 3));
      poll(_ok(delta: 0, transport: 0));
      expect(
        poll(_ok(delta: 0, transport: 0)).status,
        CallAudioHealth.inboundSilent,
      );
    });

    test('nothing at all arriving is a stall', () {
      settle();
      poll(_ok(delta: 0, transport: 0));
      expect(
        poll(_ok(delta: 0, transport: 0)).status,
        CallAudioHealth.packetStall,
      );
    });

    test('a path that stops mid-silence becomes a stall', () {
      settle();
      poll(_ok(delta: 0, transport: 3));
      for (var i = 0; i < CallAudioHealthLimits.silentPathQuietIntervals; i++) {
        poll(_ok(delta: 0, transport: 0));
      }
      expect(
        poll(_ok(delta: 0, transport: 0)).status,
        CallAudioHealth.packetStall,
      );
    });

    test('voice coming back forgets the sighting', () {
      settle();
      poll(_ok(delta: 0, transport: 3));
      poll(_ok(delta: 0, transport: 3));
      poll(_ok());
      poll(_ok(delta: 0, transport: 0));
      expect(
        poll(_ok(delta: 0, transport: 0)).status,
        CallAudioHealth.packetStall,
      );
    });
  });

  group('missing audio', () {
    test('no inbound report past the grace is no incoming audio', () {
      settle();
      final report = poll(_ok(hasInbound: false, delta: null));
      expect(report.status, CallAudioHealth.noIncomingAudio);
      expect(report.signals, contains(CallAudioSignal.missingInbound));
    });

    test('a report whose total is still zero is no incoming audio too', () {
      for (var i = 0; i < 3; i++) {
        poll(_ok(total: 0, delta: 0));
      }
      expect(
        poll(_ok(total: 0, delta: 0)).status,
        CallAudioHealth.noIncomingAudio,
      );
    });

    test('no RTP reports at all means the stats are unavailable', () {
      settle();
      final report = poll(
        _ok(hasInbound: false, hasOutbound: false, delta: null),
      );
      expect(report.status, CallAudioHealth.statsUnavailable);
      expect(report.signals, contains(CallAudioSignal.statsUnavailable));
    });

    test('a failed read is unavailable, and not counted as a stall', () {
      settle();
      poll(_ok(delta: 0));
      final report = tracker.addFailure(nowMs: now += 2000);
      expect(report.status, CallAudioHealth.statsUnavailable);
      expect(poll(_ok(delta: 0)).stalledIntervals, 2);
    });

    test('an inbound report with no packet count is unavailable', () {
      settle();
      const sample = CallAudioSample(hasInbound: true, hasOutbound: true);
      expect(poll(sample).status, CallAudioHealth.statsUnavailable);
    });
  });

  group('telling causes apart', () {
    test('a clean interval is healthy', () {
      settle();
      final report = poll(_ok());
      expect(report.status, CallAudioHealth.healthy);
      expect(report.signals, isEmpty);
    });

    test('loss is network loss, even while concealing', () {
      settle();
      final report = poll(_ok(loss: 8, concealment: 12));
      expect(report.status, CallAudioHealth.networkLoss);
      expect(
        report.signals,
        containsAll([CallAudioSignal.networkLoss, CallAudioSignal.concealing]),
      );
    });

    test('a deep jitter buffer is late audio', () {
      settle();
      final report = poll(_ok(buffer: 400));
      expect(report.status, CallAudioHealth.lateAudio);
      expect(report.signals, contains(CallAudioSignal.jitterBufferHigh));
    });

    test('concealing with no loss but high jitter is late audio', () {
      settle();
      expect(
        poll(_ok(concealment: 10, jitter: 90)).status,
        CallAudioHealth.lateAudio,
      );
    });

    test('one concealing interval claims no cause', () {
      settle();
      expect(poll(_ok(concealment: 10)).status, CallAudioHealth.concealment);
    });

    test('concealing that goes on over a clean network is the pipeline', () {
      settle();
      poll(_ok(concealment: 10));
      expect(
        poll(_ok(concealment: 10)).status,
        CallAudioHealth.pipelineInterruption,
      );
    });

    test('a clean interval between two gaps starts the count again', () {
      settle();
      poll(_ok(concealment: 10));
      poll(_ok());
      expect(poll(_ok(concealment: 10)).status, CallAudioHealth.concealment);
    });

    test('packets arriving but not being played point at the pipeline', () {
      settle();
      final report = poll(_ok(playout: 0.1));
      expect(report.status, CallAudioHealth.pipelineInterruption);
      expect(report.signals, contains(CallAudioSignal.playoutStalled));
    });

    test('concealing when loss is unknown does not guess the cause', () {
      settle();
      expect(
        poll(_ok(concealment: 10, loss: null)).status,
        CallAudioHealth.concealment,
      );
    });

    test('the fade as a peer stops talking is not a fault', () {
      settle();
      final report = poll(_ok(delta: 2, concealment: 10));
      expect(report.status, CallAudioHealth.healthy);
      expect(report.signals, contains(CallAudioSignal.concealing));
    });

    test('unsupported figures do not raise anything', () {
      settle();
      const sample = CallAudioSample(
        hasInbound: true,
        hasOutbound: true,
        packetsReceived: 1000,
        packetsReceivedDelta: 50,
        missingInboundFields: ['concealedSamples', 'jitterBufferDelay'],
      );
      final report = poll(sample);
      expect(report.status, CallAudioHealth.healthy);
      expect(report.unsupported, contains('concealedSamples'));
    });
  });
}
