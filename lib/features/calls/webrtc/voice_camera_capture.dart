import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// The phone camera as one MediaStream on a 1:1 call.
///
/// Kept apart from the microphone stream on purpose: the two start and stop
/// at different moments (the camera can be toggled mid-call, the mic never
/// closes), and a separate stream gives the track its own `msid`, which is
/// what lets the far side tell a camera from a shared screen — see
/// [VoiceMediaMap].
class VoiceCameraCapture {
  VoiceCameraCapture._(this.stream, this.front);

  final MediaStream stream;

  /// Which way the lens points. Only the front camera is mirrored in the local
  /// preview, the way every phone's own camera app does it.
  bool front;

  MediaStreamTrack get track => stream.getVideoTracks().first;

  static Future<VoiceCameraCapture> open({bool front = true}) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'facingMode': front ? 'user' : 'environment',
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '24',
        },
        'optional': <dynamic>[],
      },
    });
    if (stream.getVideoTracks().isEmpty) {
      await stream.dispose();
      throw StateError('camera returned no video track');
    }
    return VoiceCameraCapture._(stream, front);
  }

  /// Flips between the front and back lens in place — the track object and the
  /// stream survive, so no renegotiation and no flicker on the far side.
  Future<void> switchCamera() async {
    // Android reports whether the lens now facing is the front one.
    front = await Helper.switchCamera(track);
  }

  Future<void> close() async {
    for (final t in stream.getTracks()) {
      await t.stop();
    }
    await stream.dispose();
  }
}
