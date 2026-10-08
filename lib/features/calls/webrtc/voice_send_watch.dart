import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/call_network_quality.dart';
import '../voice_call_log.dart';
import 'voice_send_stats.dart';
import 'voice_video_hold.dart';

/// Watches what a 1:1 call sends: logs it, and says when the camera should
/// stop or start going out — see [VoiceVideoHold].
///
/// Fed by the engine's existing two-second stats poll; it asks for nothing
/// of its own.
class VoiceSendWatch {
  /// How often the send figures are logged while nothing changes.
  static const logEveryMs = 10 * 1000;

  final _reader = VoiceSendStatsReader();
  final _hold = VoiceVideoHold();
  int _loggedAt = 0;

  /// The user turned the camera on or off.
  void cameraChanged() => _hold.reset();

  /// The sender refused what [onStats] asked for.
  void undo(VideoHoldAction action) => _hold.undo(action);

  /// [live] is false while the media path is down: figures from a dead path
  /// are logged but decide nothing.
  VideoHoldAction onStats(
    List<StatsReport> stats,
    CallNetworkSample path, {
    required bool cameraOn,
    required bool live,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sample = _reader.read(stats, nowMs: nowMs);
    var action = VideoHoldAction.none;
    if (live) {
      action = _hold.update(
        cameraOn: cameraOn,
        availableBps: sample.availableBps,
        videoBps: sample.videoBps,
        path: rateNetworkSample(path),
        nowMs: nowMs,
      );
    } else {
      _hold.interrupt();
    }
    if (action != VideoHoldAction.none || nowMs - _loggedAt >= logEveryMs) {
      _loggedAt = nowMs;
      final camera = !cameraOn
          ? 'off'
          : _hold.held
          ? 'held'
          : 'sending';
      final change = action == VideoHoldAction.none ? '' : ' -> ${action.name}';
      voiceCallLog(
        'stats.send',
        reason:
            '${sample.describe()} path=${rateNetworkSample(path).name} '
            'camera=$camera$change',
      );
    }
    return action;
  }
}
