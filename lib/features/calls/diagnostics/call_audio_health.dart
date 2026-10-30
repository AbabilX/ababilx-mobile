import 'call_audio_health_report.dart';
import 'call_audio_stats.dart';

export 'call_audio_health_report.dart';

/// Turns each [CallAudioSample] into a [CallAudioHealthReport], remembering
/// what one reading alone cannot show: how long the call has been up, and how
/// many empty intervals ran in a row.
class CallAudioHealthTracker {
  int? _liveSinceMs;
  bool _wasLive = false;
  int _stalled = 0;

  /// Control traffic was seen during this stall; how long ago, in intervals.
  bool _pathSeen = false;
  int _pathQuiet = 0;

  /// Intervals in a row concealing on a network that looks clean. One is not
  /// enough: a network gap reads exactly like this, since packets lost at the
  /// edge of a gap are not counted lost, measured on a phone at 8.8% and 0 loss.
  int _concealRun = 0;

  CallAudioHealthReport add(
    CallAudioSample sample, {
    required int nowMs,
    required bool connected,
    required bool iceConnected,
  }) {
    final unsupported = sample.missingInboundFields;
    CallAudioHealthReport report(
      CallAudioHealth status, [
      Set<CallAudioSignal> signals = const {},
    ]) => CallAudioHealthReport(
      status: status,
      signals: signals,
      stalledIntervals: _stalled,
      unsupported: unsupported,
    );

    if (!connected || !iceConnected) {
      _liveSinceMs = null;
      _stalled = 0;
      _pathSeen = false;
      _concealRun = 0;
      return report(CallAudioHealth.settling);
    }
    final since = _liveSinceMs ??= nowMs;
    final grace = _wasLive
        ? CallAudioHealthLimits.reconnectGraceMs
        : CallAudioHealthLimits.setupGraceMs;
    if (nowMs - since < grace) return report(CallAudioHealth.settling);
    _wasLive = true;

    if (!sample.hasInbound && !sample.hasOutbound) {
      return report(CallAudioHealth.statsUnavailable, {
        CallAudioSignal.statsUnavailable,
      });
    }
    if (!sample.hasInbound || sample.packetsReceived == 0) {
      return report(CallAudioHealth.noIncomingAudio, {
        CallAudioSignal.missingInbound,
      });
    }
    if (sample.packetsReceived == null) {
      return report(CallAudioHealth.statsUnavailable, {
        CallAudioSignal.statsUnavailable,
      });
    }

    final step = sample.packetsReceivedDelta;
    // An unknown step is a new stream or a reset, not an empty interval.
    _stalled = step == 0 ? _stalled + 1 : 0;
    if (_stalled == 0) {
      _pathSeen = false;
      _pathQuiet = 0;
    } else if ((sample.transportPacketsDelta ?? 0) > 0) {
      _pathSeen = true;
      _pathQuiet = 0;
    } else {
      _pathQuiet++;
    }
    if (_stalled >= CallAudioHealthLimits.stallIntervals) {
      if (_pathSeen &&
          _pathQuiet <= CallAudioHealthLimits.silentPathQuietIntervals) {
        return report(CallAudioHealth.inboundSilent, {
          CallAudioSignal.peerSilent,
        });
      }
      return report(CallAudioHealth.packetStall, {CallAudioSignal.packetStall});
    }

    final loss = sample.lossPercent;
    final lossy = loss != null && loss >= CallAudioHealthLimits.lossPercent;
    final jitter = sample.jitterMs ?? 0;
    final buffer = sample.jitterBufferDelayMs ?? 0;
    final bufferHigh = buffer >= CallAudioHealthLimits.jitterBufferDelayMs;
    final concealing =
        (sample.concealmentPercent ?? 0) >=
        CallAudioHealthLimits.concealmentPercent;
    final judgeable =
        (step ?? 0) >= CallAudioHealthLimits.packetsToJudgeConcealment;
    final share = sample.playoutShare;
    final notPlaying =
        (step ?? 0) > 0 &&
        share != null &&
        share < CallAudioHealthLimits.playoutShare;

    final signals = {
      if (lossy) CallAudioSignal.networkLoss,
      if (bufferHigh) CallAudioSignal.jitterBufferHigh,
      if (concealing) CallAudioSignal.concealing,
      if (notPlaying) CallAudioSignal.playoutStalled,
    };
    final unexplained =
        concealing &&
        judgeable &&
        !lossy &&
        !bufferHigh &&
        !notPlaying &&
        loss != null &&
        jitter < CallAudioHealthLimits.jitterMs;
    _concealRun = unexplained ? _concealRun + 1 : 0;
    final status = switch (true) {
      _ when notPlaying => CallAudioHealth.pipelineInterruption,
      _ when lossy => CallAudioHealth.networkLoss,
      _ when bufferHigh => CallAudioHealth.lateAudio,
      _ when !concealing || !judgeable => CallAudioHealth.healthy,
      _ when jitter >= CallAudioHealthLimits.jitterMs =>
        CallAudioHealth.lateAudio,
      _ when _concealRun >= CallAudioHealthLimits.pipelineIntervals =>
        CallAudioHealth.pipelineInterruption,
      _ => CallAudioHealth.concealment,
    };
    return report(status, signals);
  }

  /// A stats read that failed says nothing about the call, so it neither
  /// counts as an empty interval nor clears the ones already counted.
  CallAudioHealthReport addFailure({required int nowMs}) =>
      CallAudioHealthReport(
        status: CallAudioHealth.statsUnavailable,
        signals: const {CallAudioSignal.statsUnavailable},
        stalledIntervals: _stalled,
      );
}
