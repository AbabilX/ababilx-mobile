import 'dart:collection';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/call_network_quality.dart';
import '../network/call_network_stats.dart';
import 'call_audio_health.dart';
import 'call_audio_stats.dart';
import 'call_connection_path.dart';
import 'call_diagnostics_state.dart';

/// Turns each stats report the call already fetched into the next
/// [CallDiagnosticsState]. Owns no timer and fetches nothing: the engine's
/// 2 s poll hands it what that poll read anyway. One per call.
class CallDiagnosticsCollector {
  final _audio = CallAudioStatsReader();
  final _health = CallAudioHealthTracker();
  final _history = ListQueue<CallDiagnosticsPoint>();
  CallDiagnosticsState? _last;

  CallDiagnosticsState add(
    List<StatsReport> stats, {
    required int nowMs,
    required CallNetworkSample network,
    required CallNetworkLevel networkLevel,
    required String? connectionState,
    required String? iceState,
  }) {
    final audio = _audio.read(stats, nowMs: nowMs);
    final health = _health.add(
      audio,
      nowMs: nowMs,
      connected: connectionState == 'connected',
      // Never heard from is not the same as down.
      iceConnected:
          iceState == null ||
          iceState == 'connected' ||
          iceState == 'completed',
    );
    _history.addLast(
      CallDiagnosticsPoint(
        atMs: nowMs,
        audio: audio,
        network: network,
        health: health.status,
      ),
    );
    while (_history.length > callDiagnosticsHistoryLength) {
      _history.removeFirst();
    }
    final available = statNum(
      selectedCandidatePair(stats)?['availableOutgoingBitrate'],
    );
    return _last = CallDiagnosticsState(
      updatedAtMs: nowMs,
      connectionState: connectionState,
      iceState: iceState,
      audio: audio,
      network: network,
      networkLevel: networkLevel,
      path: readConnectionPath(stats),
      availableOutgoingBps:
          available == null || !available.isFinite || available <= 0
          ? null
          : available.round(),
      health: health,
      history: List.unmodifiable(_history),
    );
  }

  /// `getStats` itself failed: the last figures stand, marked as such.
  CallDiagnosticsState addFailure({required int nowMs}) {
    final health = _health.addFailure(nowMs: nowMs);
    final last = _last;
    return _last = last == null
        ? CallDiagnosticsState(health: health)
        : last.withHealth(health);
  }
}

/// `RTCPeerConnectionStateConnected` -> `connected`.
String? peerStateName(Object? state) {
  if (state == null) return null;
  return state
      .toString()
      .split('.')
      .last
      .replaceFirst(RegExp(r'^RTC\w*?State(?=[A-Z])'), '')
      .toLowerCase();
}
