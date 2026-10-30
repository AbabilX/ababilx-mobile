import 'package:flutter/foundation.dart';

import '../network/call_network_quality.dart';
import 'call_audio_health.dart';
import 'call_audio_stats.dart';
import 'call_connection_path.dart';

/// Off in a production build: nothing is collected and the panel cannot be
/// reached. On in debug, or in any build given `--dart-define=CALL_DIAGNOSTICS=true`,
/// which is how a profile build on a real phone gets it.
const bool kCallDiagnosticsEnabled =
    kDebugMode || bool.fromEnvironment('CALL_DIAGNOSTICS', defaultValue: false);

/// Two minutes at the 2 s poll.
const callDiagnosticsHistoryLength = 60;

/// The live 1:1 call's latest reading; null with no call or diagnostics off.
/// Its own notifier, like `callNetworkQuality`, so a reading every 2 s rebuilds
/// the panel and nothing else on the call screen.
final ValueNotifier<CallDiagnosticsState?> callDiagnostics = ValueNotifier(
  null,
);

/// One past reading, for the two-minute view.
class CallDiagnosticsPoint {
  const CallDiagnosticsPoint({
    required this.atMs,
    required this.audio,
    required this.network,
    required this.health,
  });

  final int atMs;
  final CallAudioSample audio;
  final CallNetworkSample network;
  final CallAudioHealth health;
}

/// The history boiled down. Averages cover only readings that measured it.
class CallDiagnosticsSummary {
  const CallDiagnosticsSummary({
    required this.readings,
    required this.troubledReadings,
    this.averageLossPercent,
    this.maxLossPercent,
    this.averageJitterMs,
    this.averageRttMs,
    this.averageConcealmentPercent,
  });

  final int readings;

  /// Readings that were neither healthy nor still settling.
  final int troubledReadings;
  final double? averageLossPercent;
  final double? maxLossPercent;
  final double? averageJitterMs;
  final double? averageRttMs;
  final double? averageConcealmentPercent;
}

class CallDiagnosticsState {
  const CallDiagnosticsState({
    this.updatedAtMs,
    this.connectionState,
    this.iceState,
    this.audio = const CallAudioSample(hasInbound: false, hasOutbound: false),
    this.network = const CallNetworkSample(),
    this.networkLevel = CallNetworkLevel.unknown,
    this.path = const CallConnectionPath(),
    this.availableOutgoingBps,
    required this.health,
    this.history = const [],
  });

  /// When the figures below were read; a failed read leaves it alone.
  final int? updatedAtMs;
  final String? connectionState;
  final String? iceState;
  final CallAudioSample audio;
  final CallNetworkSample network;

  /// The level the call's own badge shows. Reported here, never decided here.
  final CallNetworkLevel networkLevel;
  final CallConnectionPath path;
  final int? availableOutgoingBps;
  final CallAudioHealthReport health;

  /// Oldest first.
  final List<CallDiagnosticsPoint> history;

  CallDiagnosticsState withHealth(CallAudioHealthReport next) =>
      CallDiagnosticsState(
        updatedAtMs: updatedAtMs,
        connectionState: connectionState,
        iceState: iceState,
        audio: audio,
        network: network,
        networkLevel: networkLevel,
        path: path,
        availableOutgoingBps: availableOutgoingBps,
        health: next,
        history: history,
      );

  CallDiagnosticsSummary get summary {
    double? mean(Iterable<double?> values) {
      final known = values.whereType<double>().where((v) => v.isFinite);
      return known.isEmpty
          ? null
          : known.reduce((a, b) => a + b) / known.length;
    }

    final losses = history.map((p) => p.audio.lossPercent).whereType<double>();
    return CallDiagnosticsSummary(
      readings: history.length,
      troubledReadings: history
          .where(
            (p) =>
                p.health != CallAudioHealth.healthy &&
                p.health != CallAudioHealth.settling,
          )
          .length,
      averageLossPercent: mean(losses),
      maxLossPercent: losses.isEmpty
          ? null
          : losses.reduce((a, b) => a > b ? a : b),
      averageJitterMs: mean(history.map((p) => p.audio.jitterMs)),
      averageRttMs: mean(history.map((p) => p.network.rttMs)),
      averageConcealmentPercent: mean(
        history.map((p) => p.audio.concealmentPercent),
      ),
    );
  }
}
