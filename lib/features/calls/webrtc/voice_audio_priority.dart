import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../voice_call_log.dart';

/// How the send budget is shared between the lanes of a 1:1 call.
///
/// WebRTC's bandwidth estimate is one figure for the whole connection. Every
/// lane first gets its minimum, and what is left is handed out in proportion
/// to these priorities until a lane reaches its own maximum. With equal
/// priorities a weak link splits the remainder evenly, so the voice sits well
/// under its 32 kbps while the picture takes the other half. Audio at `high`
/// (4.0) against video at `veryLow` (0.5) fills the voice first; video gets
/// what remains.
///
/// Nothing here estimates or limits bandwidth: the estimate, and how fast it
/// moves, stay WebRTC's own.
const RTCPriorityType kAudioSendPriority = RTCPriorityType.high;
const RTCPriorityType kVideoSendPriority = RTCPriorityType.veryLow;

/// Marks the microphone's sender as the lane to fill first.
///
/// Never fatal: a build that rejects `setParameters` still makes a call, with
/// WebRTC's even split.
Future<void> prioritizeAudioSend(RTCRtpSender sender) async {
  try {
    final params = sender.parameters;
    final encodings = params.encodings;
    if (encodings == null || encodings.isEmpty) {
      params.encodings = [RTCRtpEncoding(priority: kAudioSendPriority)];
    } else {
      for (final encoding in encodings) {
        encoding.priority = kAudioSendPriority;
      }
    }
    await sender.setParameters(params);
    voiceCallLog('audio.priority', reason: kAudioSendPriority.name);
  } catch (error) {
    voiceCallLog('audio.priority.failed', reason: error.toString());
  }
}
