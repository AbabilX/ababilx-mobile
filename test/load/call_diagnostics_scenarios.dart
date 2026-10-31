import 'dart:math';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Scripted 1:1 calls for the diagnostics load test. Plain Dart, so the same
/// file also runs on a real phone.
enum Sim {
  healthy,
  lossy,
  late,
  stall,
  blips,
  mutedDtx,
  peerMuted,
  iceRestart,
  lateInbound,
  neverInbound,
  bareFields,
  videoLoss,
  pipeline,
  playoutStall,
  readFailures,
  garbage,
}

/// What one 2 s interval of a call does.
class Tick {
  const Tick({
    this.packets = 100,
    this.transport = 106,
    this.lost = 0,
    this.jitter = 0.01,
    this.bufferMs = 60,
    this.concealPercent = 0,
    this.silent = false,
    this.playout = 1,
    this.connected = true,
    this.fail = false,
    this.inbound = true,
    this.stream = 'a',
    this.relay = false,
  });

  final int packets;
  final int transport;
  final int lost;
  final double jitter;
  final double bufferMs;
  final double concealPercent;
  final bool silent;
  final double playout;
  final bool connected;
  final bool fail;
  final bool inbound;
  final String stream;
  final bool relay;
}

Tick tickFor(Sim sim, int i) => switch (sim) {
  Sim.lossy when i > 40 => const Tick(packets: 92, lost: 8),
  Sim.late when i > 40 => const Tick(jitter: 0.09, bufferMs: 300),
  Sim.stall when i >= 40 && i < 46 => const Tick(packets: 0, transport: 0),
  // What a real phone did: a muted sender stops, RTCP and STUN carry on.
  Sim.peerMuted when i == 40 => const Tick(packets: 2, concealPercent: 10),
  Sim.peerMuted when i > 40 && i < 60 => Tick(
    packets: 0,
    transport: i % 2 == 0 ? 3 : 0,
  ),
  Sim.blips when i % 5 == 0 => const Tick(packets: 0, transport: 0),
  Sim.mutedDtx => const Tick(packets: 5, concealPercent: 40, silent: true),
  Sim.iceRestart when i >= 40 && i < 44 => const Tick(
    packets: 0,
    connected: false,
  ),
  Sim.iceRestart when i >= 44 => const Tick(stream: 'b', relay: true),
  Sim.lateInbound when i < 2 => const Tick(inbound: false, packets: 0),
  Sim.neverInbound => const Tick(inbound: false, packets: 0),
  Sim.pipeline when i > 40 => const Tick(concealPercent: 15),
  Sim.playoutStall when i > 40 => const Tick(playout: 0.1),
  Sim.readFailures when i % 7 == 0 => const Tick(fail: true),
  _ => const Tick(),
};

/// Builds what `getStats` would return for one call, counters running on.
class SimCall {
  SimCall(this.sim, int seed) : _random = Random(seed);

  final Sim sim;
  final Random _random;
  final _totals = <String, num>{};

  num _add(String key, num by) => _totals[key] = (_totals[key] ?? 0) + by;

  StatsReport _r(String id, String type, Map<String, dynamic> v) =>
      StatsReport(id, type, 0, v);

  List<StatsReport> report(Tick t) {
    final s = t.stream;
    const samples = 96000;
    final concealed = samples * t.concealPercent / 100;
    final inbound = <String, dynamic>{
      'kind': 'audio',
      'packetsReceived': _add('$s.got', t.packets),
      'packetsLost': _add('$s.lost', t.lost),
      'bytesReceived': _add('$s.bytes', t.packets * 80),
      'jitter': t.jitter,
      'jitterBufferDelay': _add('$s.delay', samples * t.bufferMs / 1000),
      'jitterBufferEmittedCount': _add('$s.emitted', samples),
      'concealedSamples': _add('$s.concealed', concealed),
      'silentConcealedSamples': _add('$s.silent', t.silent ? concealed : 0),
      'concealmentEvents': _add('$s.events', t.concealPercent > 0 ? 3 : 0),
      'totalSamplesReceived': _add('$s.samples', samples),
      'totalSamplesDuration': _add('$s.played', 2 * t.playout),
      'audioLevel': 0.2,
      'codecId': 'cr',
    };
    final videoLost = sim == Sim.videoLoss ? 500 : 0;
    final stats = [
      _r('tr', 'transport', {
        'selectedCandidatePairId': t.relay ? 'p2' : 'p1',
        'packetsReceived': _add('tr.got', t.transport),
      }),
      _r('p1', 'candidate-pair', {
        'localCandidateId': 'l1',
        'remoteCandidateId': 'r1',
        'state': 'succeeded',
        'nominated': true,
        'currentRoundTripTime': 0.05,
        'availableOutgoingBitrate': 90000.0,
      }),
      _r('p2', 'candidate-pair', {
        'localCandidateId': 'l2',
        'remoteCandidateId': 'r1',
        'state': 'succeeded',
        'nominated': true,
      }),
      _r('l1', 'local-candidate', _candidate('srflx')),
      _r('l2', 'local-candidate', {
        ..._candidate('relay'),
        'relayProtocol': 'tcp',
      }),
      _r('r1', 'remote-candidate', _candidate('host')),
      if (t.inbound)
        _r(
          'in-$s',
          'inbound-rtp',
          sim == Sim.bareFields
              ? {'kind': 'audio', 'packetsReceived': inbound['packetsReceived']}
              : inbound,
        ),
      _r('in-v', 'inbound-rtp', {
        'kind': 'video',
        'packetsReceived': _add('v.got', 500),
        'packetsLost': _add('v.lost', videoLost),
      }),
      _r('out-a', 'outbound-rtp', {
        'kind': 'audio',
        'bytesSent': _add('out.bytes', 8000),
        'packetsSent': _add('out.pkts', 100),
        'codecId': 'cs',
      }),
      _r('ra', 'remote-inbound-rtp', {'kind': 'audio', 'fractionLost': 0.01}),
      _r('cr', 'codec', {'mimeType': 'audio/opus'}),
      _r('cs', 'codec', {'mimeType': 'audio/opus'}),
    ];
    return sim == Sim.garbage ? stats.map(_spoil).toList() : stats;
  }

  static Map<String, dynamic> _candidate(String type) => {
    'candidateType': type,
    'protocol': 'udp',
    'address': '203.0.113.7',
    'port': 40000,
    'usernameFragment': 'ufragvalue',
  };

  /// Replaces about a third of the values with what no spec promises away.
  StatsReport _spoil(StatsReport report) {
    const junk = <Object?>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
      'NaN',
      'Infinity',
      '-Infinity',
      'x',
      '',
      null,
      -1,
      -0.5,
      1e308,
      9007199254740993,
      <String>['x'],
      <String, int>{'x': 1},
      true,
      '203.0.113.7',
    ];
    final values = <dynamic, dynamic>{
      for (final e in report.values.entries)
        e.key: _random.nextInt(3) == 0
            ? junk[_random.nextInt(junk.length)]
            : e.value,
    };
    return StatsReport(report.id, report.type, 0, values.cast());
  }
}
