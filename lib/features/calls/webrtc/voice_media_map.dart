import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Which remote video stream is the camera and which is the screen.
///
/// Two video tracks on one peer connection are indistinguishable on the wire.
/// The sender tells us with a `media` signal carrying its MediaStream ids,
/// sent ahead of the offer/answer that adds or removes a track — so by the
/// time `onTrack` fires the id is already known. A peer that never sends one
/// (an older build) has only ever sent a screen, which is what the fallback
/// keeps drawing.
class VoiceMediaMap {
  String? cameraId;
  String? screenId;
  bool received = false;

  /// Every remote video stream we have been handed, by id. Kept even while
  /// the far side has its camera off: the track only mutes — the stream
  /// object is reused when they turn it back on without renegotiating.
  final Map<String, MediaStream> streams = {};

  void apply(Map<String, dynamic> signal) {
    received = true;
    cameraId = _id(signal['camera_stream']);
    screenId = _id(signal['screen_stream']);
  }

  static String? _id(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  MediaStream? get camera => cameraId == null ? null : streams[cameraId];

  MediaStream? get screen {
    if (screenId != null) return streams[screenId];
    if (received) return null;
    // Legacy peer: no map ever arrived, so the only video it can send is a
    // screen share — the newest stream we hold.
    return streams.values.isEmpty ? null : streams.values.last;
  }

  /// The peer has named a stream we are not receiving yet: it has just added
  /// a track, and that track may need a transceiver of ours to arrive on.
  bool get awaiting =>
      [cameraId, screenId].any((id) => id != null && !streams.containsKey(id));

  void clear() {
    streams.clear();
    cameraId = null;
    screenId = null;
  }
}
