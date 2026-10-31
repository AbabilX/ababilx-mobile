import 'dart:math' as math;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/call_network_stats.dart';
import '../voice_call_log.dart';

/// Off until a listening test says otherwise: on a phone the rule stepped down
/// with no clear gain and held 16 kbps for a while after the link cleared.
/// `--dart-define=CALL_AUDIO_CAP=true` builds a phone with it on, to compare by
/// ear.
const kVoiceAudioCapEnabled = bool.fromEnvironment('CALL_AUDIO_CAP');

/// The rate voice drops to. Measured on a phone: 16 kbps cleared all loss on a
/// 48 kbps link where the default 32 kbps lost 12.7%. Below about 32 kbps of
/// link the packet headers alone do not fit, and a cap cannot help.
const kVoiceCappedBps = 16000;

/// Opus's default target here. Lifting must name it: the plugin ignores a null
/// `maxBitrate`, and a higher figure would raise the target above where the
/// call began.
const kVoiceFullBps = 32000;

enum VoiceCapAction { none, cap, lift }

/// Decides when this phone's voice steps down on a link too thin for it, and
/// when it goes back up.
///
/// WebRTC does not do this: the voice target stays 32 kbps down to a 12 kbps
/// link (measured), and `availableOutgoingBitrate` floors near 54 kbps, so it
/// cannot be the signal. **Congestion** is the peer reporting loss of our voice
/// while the round trip has climbed above the path's own floor. Loss on a flat
/// round trip is a bad radio, where a lower rate only sounds worse.
///
/// There is no way to see the link recovered while capped, so it goes back up
/// after a calm hold, and each try that fails doubles the next hold.
class VoiceAudioCap {
  static const lossPercent = 5.0;
  static const queueRiseMs = 80.0;
  static const calmRiseMs = 40.0;
  static const calmLossPercent = 2.0;
  static const congestedPolls = 2;
  static const firstHoldMs = 30 * 1000;
  static const maxHoldMs = 240 * 1000;

  /// Full rate lasting this long was a real recovery: the hold starts over.
  static const calmMs = 120 * 1000;

  bool _capped = false;
  int _holdMs = firstHoldMs;
  int _congested = 0;
  int? _calmSince;
  int? _liftedAt;
  double? _floorRttMs;
  Object? _pathKey;

  bool get capped => _capped;
  double? get floorRttMs => _floorRttMs;

  VoiceCapAction update({
    required double? remoteLossPercent,
    required double? rttMs,
    required Object? pathKey,
    required bool videoSending,
    required bool live,
    required int nowMs,
  }) {
    if (!live) {
      _congested = 0;
      _calmSince = null;
      return VoiceCapAction.none;
    }
    if (pathKey != null && pathKey != _pathKey) {
      final moved = _pathKey != null;
      _pathKey = pathKey;
      _floorRttMs = rttMs;
      _congested = 0;
      _calmSince = null;
      if (moved && _capped) return _lift(nowMs);
      return VoiceCapAction.none;
    }
    if (rttMs == null) return VoiceCapAction.none;
    final floor = math.min(_floorRttMs ?? rttMs, rttMs);
    _floorRttMs = floor;
    final rise = rttMs - floor;
    return _capped
        ? _whileCapped(rise, remoteLossPercent, nowMs)
        : _atFullRate(rise, remoteLossPercent, videoSending, nowMs);
  }

  VoiceCapAction _atFullRate(
    double rise,
    double? loss,
    bool videoSending,
    int nowMs,
  ) {
    // With a picture going out the voice is not what fills the link, and the
    // camera hold already deals with that.
    final congested =
        !videoSending &&
        loss != null &&
        loss >= lossPercent &&
        rise >= queueRiseMs;
    _congested = congested ? _congested + 1 : 0;
    if (_congested < congestedPolls) return VoiceCapAction.none;
    _congested = 0;
    _capped = true;
    _calmSince = null;
    final liftedAt = _liftedAt;
    _holdMs = liftedAt != null && nowMs - liftedAt < calmMs
        ? math.min(_holdMs * 2, maxHoldMs)
        : firstHoldMs;
    return VoiceCapAction.cap;
  }

  VoiceCapAction _whileCapped(double rise, double? loss, int nowMs) {
    final calm = rise < calmRiseMs && (loss ?? 0) < calmLossPercent;
    if (!calm) {
      _calmSince = null;
      return VoiceCapAction.none;
    }
    final since = _calmSince ??= nowMs;
    return nowMs - since >= _holdMs ? _lift(nowMs) : VoiceCapAction.none;
  }

  VoiceCapAction _lift(int nowMs) {
    _capped = false;
    _liftedAt = nowMs;
    _calmSince = null;
    return VoiceCapAction.lift;
  }

  /// The sender refused what [update] asked for: as if it was never asked.
  void undo(VoiceCapAction action) {
    if (action == VoiceCapAction.cap) _capped = false;
    if (action == VoiceCapAction.lift) _capped = true;
  }
}

/// What the peer says it lost of our voice, in percent; video is not counted,
/// since this decides the voice's rate. Null when nothing usable was reported.
double? audioRemoteLossPercent(List<StatsReport> stats) {
  double? worst;
  for (final report in stats) {
    if (report.type != 'remote-inbound-rtp') continue;
    final v = report.values;
    if ((v['kind'] ?? v['mediaType']) != 'audio') continue;
    final fraction = statNum(v['fractionLost']);
    if (fraction == null || !fraction.isFinite || fraction < 0) continue;
    worst = math.max(worst ?? 0, fraction * 100);
  }
  return worst;
}

/// Sets the voice's top rate. Never fatal, and tells the caller if it failed.
Future<bool> setAudioSendCap(RTCRtpSender sender, int bps) async {
  try {
    final params = sender.parameters;
    final encodings = params.encodings;
    if (encodings == null || encodings.isEmpty) {
      params.encodings = [RTCRtpEncoding(maxBitrate: bps)];
    } else {
      for (final encoding in encodings) {
        encoding.maxBitrate = bps;
      }
    }
    await sender.setParameters(params);
    return true;
  } catch (error) {
    voiceCallLog('audio.cap.failed', reason: error.runtimeType.toString());
    return false;
  }
}
