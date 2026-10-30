import 'package:ababilx/features/calls/diagnostics/call_audio_health.dart';
import 'package:ababilx/features/calls/diagnostics/call_audio_stats.dart';
import 'package:ababilx/features/calls/diagnostics/call_connection_path.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_collector.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_format.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_state.dart';
import 'package:ababilx/features/calls/network/call_network_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

List<StatsReport> _stats(int packets, {int lost = 0, String pair = 'p1'}) => [
  StatsReport('t', 'transport', 0, {'selectedCandidatePairId': pair}),
  StatsReport('p1', 'candidate-pair', 0, {
    'localCandidateId': 'l1',
    'remoteCandidateId': 'r1',
    'availableOutgoingBitrate': 90000.0,
  }),
  StatsReport('p2', 'candidate-pair', 0, {
    'localCandidateId': 'l2',
    'remoteCandidateId': 'r1',
  }),
  StatsReport('l1', 'local-candidate', 0, {
    'candidateType': 'srflx',
    'protocol': 'udp',
    'address': '203.0.113.7',
  }),
  StatsReport('l2', 'local-candidate', 0, {
    'candidateType': 'relay',
    'protocol': 'udp',
    'address': '203.0.113.7',
  }),
  StatsReport('r1', 'remote-candidate', 0, {
    'candidateType': 'host',
    'protocol': 'udp',
    'address': '198.51.100.9',
  }),
  StatsReport('ia', 'inbound-rtp', 0, {
    'kind': 'audio',
    'packetsReceived': packets,
    'packetsLost': lost,
    'bytesReceived': packets * 100,
  }),
  StatsReport('oa', 'outbound-rtp', 0, {
    'kind': 'audio',
    'bytesSent': packets * 100,
    'packetsSent': packets,
  }),
];

void main() {
  late CallDiagnosticsCollector collector;
  var now = 0;

  CallDiagnosticsState add(List<StatsReport> stats) {
    now += 2000;
    return collector.add(
      stats,
      nowMs: now,
      network: const CallNetworkSample(rttMs: 80),
      networkLevel: CallNetworkLevel.good,
      connectionState: 'connected',
      iceState: 'connected',
    );
  }

  setUp(() {
    collector = CallDiagnosticsCollector();
    now = 0;
  });

  test('one reading carries every part of the state', () {
    add(_stats(100));
    final state = add(_stats(200));
    expect(state.updatedAtMs, 4000);
    expect(state.connectionState, 'connected');
    expect(state.iceState, 'connected');
    expect(state.audio.packetsReceivedDelta, 100);
    expect(state.network.rttMs, 80);
    expect(state.networkLevel, CallNetworkLevel.good);
    expect(state.path.kind, CallPathKind.direct);
    expect(state.availableOutgoingBps, 90000);
    expect(state.health.status, CallAudioHealth.settling);
  });

  test('the history keeps the last 60 readings, oldest first', () {
    late CallDiagnosticsState state;
    for (var i = 1; i <= 75; i++) {
      state = add(_stats(i * 10));
    }
    expect(state.history, hasLength(callDiagnosticsHistoryLength));
    expect(callDiagnosticsHistoryLength, 60);
    expect(state.history.last.atMs, state.updatedAtMs);
    expect(state.history.first.atMs, state.updatedAtMs! - 59 * 2000);
    expect(() => state.history.clear(), throwsUnsupportedError);
  });

  test('the two-minute summary averages only what was measured', () {
    add(_stats(100));
    add(_stats(190, lost: 10));
    final state = add(_stats(280, lost: 10));
    final summary = state.summary;
    expect(summary.readings, 3);
    expect(summary.averageLossPercent, 5);
    expect(summary.maxLossPercent, 10);
  });

  test('a failed read keeps the last figures and says so', () {
    add(_stats(100));
    final before = add(_stats(200));
    final failed = collector.addFailure(nowMs: now += 2000);
    expect(failed.health.status, CallAudioHealth.statsUnavailable);
    expect(failed.audio.packetsReceived, before.audio.packetsReceived);
    expect(failed.updatedAtMs, before.updatedAtMs);
  });

  test('a failed first read still yields a state', () {
    final failed = collector.addFailure(nowMs: 1);
    expect(failed.health.status, CallAudioHealth.statsUnavailable);
    expect(failed.history, isEmpty);
  });

  test('moving to another pair is seen on the next reading', () {
    final first = add(_stats(100));
    expect(first.path.kind, CallPathKind.direct);
    final moved = add(_stats(200, pair: 'p2'));
    expect(moved.path.kind, CallPathKind.relay);
    expect(moved.path.pairKey, isNot(first.path.pairKey));
  });

  test('a report that cannot be read does not reach the caller as a throw', () {
    final state = add([
      StatsReport('ia', 'inbound-rtp', 0, {'kind': 'audio', 'jitter': {}}),
    ]);
    expect(state.audio.jitterMs, isNull);
  });

  group('panel text', () {
    test('a missing figure reads n/a, never zero', () {
      expect(formatMs(null), 'n/a');
      expect(formatPercent(null), 'n/a');
      expect(formatBitrate(null), 'n/a');
      expect(formatMs(12.4), '12 ms');
      expect(formatPercent(1.25), '1.3 %');
      expect(formatBitrate(32000), '32 kbps');
    });

    test('a non-finite figure reads n/a instead of throwing in build', () {
      for (final v in [double.nan, double.infinity]) {
        expect(formatMs(v), 'n/a');
        expect(formatPercent(v), 'n/a');
        expect(formatBitrate(v), 'n/a');
        expect(formatCount(v), 'n/a');
      }
    });

    test('path text says P2P or TURN, and when it is unconfirmed', () {
      expect(pathLabel(const CallConnectionPath()), 'Unknown');
      expect(
        pathLabel(
          const CallConnectionPath(
            localType: 'srflx',
            remoteType: 'host',
            confirmedByTransport: true,
          ),
        ),
        'P2P',
      );
      expect(
        pathLabel(const CallConnectionPath(localType: 'relay')),
        'TURN relay (unconfirmed)',
      );
    });

    test('transport text carries the relay leg', () {
      expect(transportLabel(const CallConnectionPath()), 'n/a');
      expect(transportLabel(const CallConnectionPath(protocol: 'udp')), 'UDP');
      expect(
        transportLabel(
          const CallConnectionPath(protocol: 'udp', relayProtocol: 'tcp'),
        ),
        'UDP (to TURN: TCP)',
      );
    });

    test('every health value has words', () {
      for (final value in CallAudioHealth.values) {
        expect(healthLabel(value), isNotEmpty);
      }
    });

    test('nothing in the state text holds an address', () {
      final state = add(_stats(100));
      expect(
        '${pathLabel(state.path)} ${transportLabel(state.path)} '
        '${state.path.describe()}',
        isNot(contains('203.0.113.7')),
      );
    });
  });

  test('peer state names lose their enum prefix', () {
    expect(
      peerStateName(RTCPeerConnectionState.RTCPeerConnectionStateConnected),
      'connected',
    );
    expect(
      peerStateName(RTCIceConnectionState.RTCIceConnectionStateCompleted),
      'completed',
    );
    expect(peerStateName(null), isNull);
  });

  test('a sample without inbound keeps empty defaults', () {
    const sample = CallAudioSample(hasInbound: false, hasOutbound: false);
    expect(sample.missingInboundFields, isEmpty);
  });
}
