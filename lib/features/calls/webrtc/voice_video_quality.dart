import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../voice_call_log.dart';
import 'voice_audio_priority.dart';

/// Send-side limits for the two video lanes of a 1:1 call.
///
/// WebRTC's default is to use whatever the path appears to allow, which on a
/// phone camera means 2 Mbps or more. A 1:1 call that cannot find a direct
/// route runs every byte through coturn, and a stream that size regularly
/// congested the relay: the pair went `disconnected`, the reconnect loop
/// restarted ICE, and the call was declared dead two minutes later. Audio
/// never hit this because it is ~50 kbps.
///
/// The camera is capped harder than the screen. A talking head survives a low
/// bitrate; shared text does not, so the screen keeps resolution and drops
/// frames instead.
const int kCameraMaxBitrate = 800 * 1000;
const int kScreenMaxBitrate = 1200 * 1000;

/// Applies a send cap to one video sender.
///
/// Never fatal: a device or build that rejects `setParameters` still makes a
/// call, it just makes an uncapped one.
Future<void> capVideoSendBitrate(
  RTCRtpSender sender, {
  required int maxBitrate,
  required bool maintainResolution,
}) async {
  try {
    final params = sender.parameters;
    final encodings = params.encodings;
    if (encodings == null || encodings.isEmpty) {
      params.encodings = [
        RTCRtpEncoding(maxBitrate: maxBitrate, priority: kVideoSendPriority),
      ];
    } else {
      for (final encoding in encodings) {
        encoding.maxBitrate = maxBitrate;
        // Behind the voice when the link cannot carry both in full.
        encoding.priority = kVideoSendPriority;
      }
    }
    params.degradationPreference = maintainResolution
        ? RTCDegradationPreference.MAINTAIN_RESOLUTION
        : RTCDegradationPreference.MAINTAIN_FRAMERATE;
    await sender.setParameters(params);
    voiceCallLog('video.bitrate.cap', reason: 'max=$maxBitrate');
  } catch (error) {
    voiceCallLog('video.bitrate.cap.failed', reason: error.toString());
  }
}
