import 'package:flutter/foundation.dart';

/// How well a 1:1 call's media path is carrying the call right now.
enum CallNetworkLevel { unknown, good, weak, poor }

/// What the live 1:1 call measured last. One call at a time owns it (see
/// `LiveCall`); it is [CallNetworkLevel.unknown] whenever no call is
/// connected, so the call screen draws nothing.
final ValueNotifier<CallNetworkLevel> callNetworkQuality = ValueNotifier(
  CallNetworkLevel.unknown,
);

/// This phone's own link to AbabilX, measured while a call is still ringing
/// or connecting — before there is a media path to measure. It says "your
/// network is fine", never "the call will be": the other side is unknown
/// until they answer.
final ValueNotifier<CallNetworkLevel> callOwnLinkQuality = ValueNotifier(
  CallNetworkLevel.unknown,
);

/// True while the live 1:1 call is holding this phone's camera back because
/// the link cannot carry voice and picture together — see `VoiceVideoHold`.
/// The camera is still on; nothing of it is being sent.
final ValueNotifier<bool> callVideoHeld = ValueNotifier(false);

/// The level one round trip to the server deserves; null is one that failed
/// or timed out. A request is slower than a media packet (TLS, HTTP, the
/// server's own work), so the bar sits higher than [rateNetworkSample]'s.
CallNetworkLevel rateOwnLink(int? roundTripMs) {
  if (roundTripMs == null || roundTripMs >= 1000) return CallNetworkLevel.poor;
  if (roundTripMs >= 400) return CallNetworkLevel.weak;
  return CallNetworkLevel.good;
}

/// One reading of the media path. A null field was not measurable this time.
class CallNetworkSample {
  const CallNetworkSample({this.rttMs, this.lossPercent, this.jitterMs});

  final double? rttMs;
  final double? lossPercent;
  final double? jitterMs;

  bool get empty => rttMs == null && lossPercent == null && jitterMs == null;
}

/// The level one [sample] deserves on its own. The worst measure decides:
/// a fast path that loses a tenth of its packets is still a bad call.
///
/// Thresholds are for speech. Opus hides a few percent of loss and people
/// stop noticing delay under ~300 ms round trip; past 600 ms, or one packet
/// in ten gone, a conversation breaks down.
CallNetworkLevel rateNetworkSample(CallNetworkSample sample) {
  if (sample.empty) return CallNetworkLevel.unknown;
  final rtt = sample.rttMs ?? 0;
  final loss = sample.lossPercent ?? 0;
  final jitter = sample.jitterMs ?? 0;
  if (rtt >= 600 || loss >= 10 || jitter >= 100) return CallNetworkLevel.poor;
  if (rtt >= 300 || loss >= 3 || jitter >= 40) return CallNetworkLevel.weak;
  return CallNetworkLevel.good;
}

/// Turns a stream of readings into a level that does not flicker.
///
/// A single late packet must not flash a warning, and one clean reading in
/// the middle of a bad stretch must not clear it: getting worse takes two
/// readings in a row, getting better takes three.
class CallNetworkTrend {
  CallNetworkLevel _level = CallNetworkLevel.unknown;
  CallNetworkLevel _candidate = CallNetworkLevel.unknown;
  int _streak = 0;

  CallNetworkLevel get level => _level;

  CallNetworkLevel add(CallNetworkSample sample) =>
      addLevel(rateNetworkSample(sample));

  CallNetworkLevel addLevel(CallNetworkLevel rated) {
    // Nothing measurable says nothing either way.
    if (rated == CallNetworkLevel.unknown) return _level;
    if (_level == CallNetworkLevel.unknown) return _level = rated;
    if (rated == _level) {
      _streak = 0;
      return _level;
    }
    if (rated != _candidate) {
      _candidate = rated;
      _streak = 0;
    }
    _streak++;
    final needed = rated.index > _level.index ? 2 : 3;
    if (_streak >= needed) {
      _level = rated;
      _streak = 0;
    }
    return _level;
  }
}
