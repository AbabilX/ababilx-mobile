import 'dart:math' as math;

import '../network/call_network_quality.dart';

/// What the rule below asks of the camera's sender.
enum VideoHoldAction { none, hold, resume }

/// Decides when a 1:1 call stops sending this phone's camera so the voice
/// keeps the link, and when the picture may go out again.
///
/// It reads WebRTC's own figures and estimates nothing itself. Bandwidth is
/// still WebRTC's to judge; this only answers "is a picture worth sending at
/// all right now", the way a person would turn the camera off by hand.
///
/// **Hold** — the send estimate has stayed under [starvedBelowBps] for
/// [starvedForMs] while the picture was really taking a share of it. Under
/// that figure a voice at full rate and the encoder's 30 kbps floor do not
/// both fit, and what the picture gets is too little to be worth watching.
///
/// **Resume** — the estimate cannot say when the link is back: with only the
/// voice going out WebRTC has nothing to measure a bigger path with. So the
/// picture is tried again once the voice's own path has rated good for a
/// while, and each try that is held again doubles the wait before the next.
class VoiceVideoHold {
  static const starvedBelowBps = 100 * 1000;

  /// Below this the picture is not what is taking the link (a covered lens,
  /// a paused app), and stopping it would give the voice nothing.
  static const videoShareBps = 20 * 1000;

  static const starvedForMs = 8 * 1000;

  /// A camera that has just started — or just come back — begins from a low
  /// estimate that WebRTC raises over a few seconds. Not judged until then.
  static const settleMs = 12 * 1000;

  static const firstWaitMs = 10 * 1000;
  static const maxWaitMs = 120 * 1000;

  /// A picture that lasted this long after coming back was a real recovery:
  /// the next hold starts from the short wait again.
  static const calmMs = 60 * 1000;

  bool _held = false;
  int _waitMs = firstWaitMs;
  int? _sendingSince;
  int? _starvedSince;
  int? _goodSince;
  int? _resumedAt;

  bool get held => _held;

  /// The camera was turned off or on by the user: nothing carries over.
  void reset() {
    _held = false;
    _waitMs = firstWaitMs;
    _sendingSince = _starvedSince = _goodSince = _resumedAt = null;
  }

  /// The media path dropped. Readings on either side of the gap are not one
  /// stretch, and a path that has just come back gets time to settle.
  void interrupt() {
    _starvedSince = _goodSince = null;
    if (!_held) _sendingSince = null;
  }

  /// The sender refused the change [action] asked for. Back to the state
  /// before it, so the same question is asked again in its own time.
  void undo(VideoHoldAction action) {
    switch (action) {
      case VideoHoldAction.hold:
        _held = false;
        _sendingSince = null;
      case VideoHoldAction.resume:
        _held = true;
        _goodSince = null;
      case VideoHoldAction.none:
        break;
    }
  }

  VideoHoldAction update({
    required bool cameraOn,
    required int? availableBps,
    required int? videoBps,
    required CallNetworkLevel path,
    required int nowMs,
  }) {
    if (!cameraOn) {
      reset();
      return VideoHoldAction.none;
    }
    if (_held) {
      if (path != CallNetworkLevel.good) {
        _goodSince = null;
        return VideoHoldAction.none;
      }
      final since = _goodSince ??= nowMs;
      if (nowMs - since < _waitMs) return VideoHoldAction.none;
      _held = false;
      _starvedSince = _goodSince = null;
      _sendingSince = _resumedAt = nowMs;
      _waitMs = math.min(_waitMs * 2, maxWaitMs);
      return VideoHoldAction.resume;
    }
    final since = _sendingSince ??= nowMs;
    if (nowMs - since < settleMs) {
      _starvedSince = null;
      return VideoHoldAction.none;
    }
    final resumed = _resumedAt;
    if (resumed != null && nowMs - resumed >= calmMs) {
      _waitMs = firstWaitMs;
      _resumedAt = null;
    }
    final starved =
        availableBps != null &&
        availableBps < starvedBelowBps &&
        videoBps != null &&
        videoBps >= videoShareBps;
    if (!starved) {
      _starvedSince = null;
      return VideoHoldAction.none;
    }
    final low = _starvedSince ??= nowMs;
    if (nowMs - low < starvedForMs) return VideoHoldAction.none;
    _held = true;
    _starvedSince = _goodSince = null;
    return VideoHoldAction.hold;
  }
}
