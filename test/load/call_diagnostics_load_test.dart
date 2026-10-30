import 'dart:io';

import 'package:ababilx/features/calls/diagnostics/call_audio_health.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_collector.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_format.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_state.dart';
import 'package:ababilx/features/calls/network/call_network_quality.dart';
import 'package:flutter_test/flutter_test.dart';

import 'call_diagnostics_scenarios.dart';

/// Thousands of simulated 1:1 calls through the real diagnostics code, each
/// polled like the engine polls. A phone only ever runs one, so this proves
/// the logic under every shape of report and prices a single poll; it says
/// nothing about servers, which this code never talks to.
///
/// `LOAD=1 flutter test test/load/call_diagnostics_load_test.dart`, sized by
/// `CALLS` (default 12000) and `POLLS` (default 150, five minutes of call).
const _allowed = <Sim, Set<CallAudioHealth>>{
  Sim.healthy: {CallAudioHealth.healthy},
  Sim.lossy: {CallAudioHealth.healthy, CallAudioHealth.networkLoss},
  Sim.late: {CallAudioHealth.healthy, CallAudioHealth.lateAudio},
  Sim.stall: {CallAudioHealth.healthy, CallAudioHealth.packetStall},
  Sim.blips: {CallAudioHealth.healthy},
  Sim.mutedDtx: {CallAudioHealth.healthy},
  Sim.peerMuted: {CallAudioHealth.healthy, CallAudioHealth.inboundSilent},
  Sim.iceRestart: {CallAudioHealth.healthy},
  Sim.lateInbound: {CallAudioHealth.healthy},
  Sim.neverInbound: {CallAudioHealth.noIncomingAudio},
  Sim.bareFields: {CallAudioHealth.healthy},
  Sim.videoLoss: {CallAudioHealth.healthy},
  Sim.pipeline: {
    CallAudioHealth.healthy,
    CallAudioHealth.concealment,
    CallAudioHealth.pipelineInterruption,
  },
  Sim.playoutStall: {
    CallAudioHealth.healthy,
    CallAudioHealth.pipelineInterruption,
  },
  Sim.readFailures: {CallAudioHealth.healthy, CallAudioHealth.statsUnavailable},
};

const _required = <Sim, CallAudioHealth>{
  Sim.lossy: CallAudioHealth.networkLoss,
  Sim.late: CallAudioHealth.lateAudio,
  Sim.stall: CallAudioHealth.packetStall,
  Sim.peerMuted: CallAudioHealth.inboundSilent,
  Sim.neverInbound: CallAudioHealth.noIncomingAudio,
  Sim.pipeline: CallAudioHealth.pipelineInterruption,
  Sim.playoutStall: CallAudioHealth.pipelineInterruption,
  Sim.readFailures: CallAudioHealth.statsUnavailable,
};

bool _finite(num? v) => v == null || v.isFinite;

/// What must hold for every reading, whatever the report said.
String? _broken(CallDiagnosticsState s) {
  final a = s.audio;
  final numbers = <num?>[
    a.lossPercent,
    a.remoteLossPercent,
    a.jitterMs,
    a.jitterBufferDelayMs,
    a.concealmentPercent,
    a.playoutShare,
    a.audioLevel,
  ];
  if (!numbers.every(_finite)) return 'non-finite figure';
  if ((a.lossPercent ?? 0) < 0) return 'negative loss';
  if ((a.inboundBps ?? 0) < 0 || (a.outboundBps ?? 0) < 0) {
    return 'negative bps';
  }
  if ((a.packetsReceivedDelta ?? 0) < 0) return 'negative packet step';
  if (s.history.length > callDiagnosticsHistoryLength) return 'history grew';
  final summary = s.summary;
  final text = [
    pathLabel(s.path),
    transportLabel(s.path),
    candidatesLabel(s.path),
    s.path.describe(),
    formatPercent(a.lossPercent),
    formatMs(a.jitterMs),
    formatBitrate(a.inboundBps),
    formatPercent(summary.averageLossPercent),
    formatMs(summary.averageRttMs),
  ].join(' ');
  if (text.contains('203.0.113') || text.contains('ufragvalue')) {
    return 'network identifier in text: $text';
  }
  if (text.contains('null') || text.contains('NaN')) return 'bad text: $text';
  return null;
}

class _Result {
  int polls = 0;
  int unsafeThrows = 0;
  final failures = <String>{};
  final seen = <Sim, Set<CallAudioHealth>>{};
}

/// Every call polled once per round, so all of them are live at the same time.
_Result _run(int calls, int polls, {Stopwatch? clock}) {
  final result = _Result();
  final fleet = [
    for (var c = 0; c < calls; c++)
      (
        call: SimCall(Sim.values[c % Sim.values.length], c),
        collector: CallDiagnosticsCollector(),
      ),
  ];
  for (var i = 0; i < polls; i++) {
    final nowMs = (i + 1) * 2000;
    for (final m in fleet) {
      final sim = m.call.sim;
      final tick = tickFor(sim, i);
      final stats = m.call.report(tick);
      clock?.start();
      final CallDiagnosticsState state;
      try {
        state = tick.fail
            ? m.collector.addFailure(nowMs: nowMs)
            : m.collector.add(
                stats,
                nowMs: nowMs,
                network: const CallNetworkSample(rttMs: 50),
                networkLevel: CallNetworkLevel.good,
                connectionState: tick.connected ? 'connected' : 'disconnected',
                iceState: tick.connected ? 'connected' : 'disconnected',
              );
      } catch (error) {
        result.unsafeThrows++;
        result.failures.add('$sim threw ${error.runtimeType}: $error');
        continue;
      } finally {
        clock?.stop();
      }
      result.polls++;
      final broken = _broken(state);
      if (broken != null) result.failures.add('$sim: $broken');
      final status = state.health.status;
      (result.seen[sim] ??= {}).add(status);
      final allowed = _allowed[sim];
      if (allowed != null &&
          status != CallAudioHealth.settling &&
          !allowed.contains(status)) {
        result.failures.add('$sim poll $i read $status');
      }
      if (sim == Sim.videoLoss && (state.audio.lossPercent ?? 0) != 0) {
        result.failures.add('video loss reached the voice figure');
      }
    }
  }
  for (final entry in _required.entries) {
    if (result.seen[entry.key]?.contains(entry.value) != true) {
      result.failures.add('${entry.key} never read ${entry.value}');
    }
  }
  return result;
}

void main() {
  final env = Platform.environment;
  final enabled = env['LOAD'] == '1';

  test('every kind of call reads as it should', () {
    final result = _run(Sim.values.length * 3, 120);
    expect(result.failures, isEmpty);
    expect(result.unsafeThrows, 0);
  });

  test(
    '10k+ calls at once: nothing throws, nothing false, memory bounded',
    () {
      final calls = int.parse(env['CALLS'] ?? '12000');
      final polls = int.parse(env['POLLS'] ?? '150');
      final clock = Stopwatch();
      final rssBefore = ProcessInfo.currentRss;
      final result = _run(calls, polls, clock: clock);
      final perPollUs = clock.elapsedMicroseconds / result.polls;
      // ignore: avoid_print
      print(
        'calls=$calls polls=${result.polls} throws=${result.unsafeThrows} '
        'perPoll=${perPollUs.toStringAsFixed(1)}us '
        'rssPeak=${(ProcessInfo.maxRss / 1048576).round()}MB '
        'rssBefore=${(rssBefore / 1048576).round()}MB',
      );
      expect(result.failures, isEmpty);
      expect(result.unsafeThrows, 0);
      // A poll every 2 s: under 1 ms is under 0.05% of one core.
      expect(perPollUs, lessThan(1000));
    },
    skip: enabled ? false : 'set LOAD=1',
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
