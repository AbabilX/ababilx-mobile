import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordedVoiceMessage {
  const RecordedVoiceMessage({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.duration,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final Duration duration;

  static const contentType = 'audio/mp4';
}

/// Android audio-only recorder backed by the WebRTC audio device already used
/// by voice calls. This avoids adding another large native recorder dependency.
class VoiceMessageRecorder {
  MediaRecorder? _recorder;
  MediaStream? _stream;
  DateTime? _startedAt;
  String? _path;

  bool get active => _recorder != null;

  Future<void> start() async {
    if (active) return;
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      throw StateError('microphone permission denied');
    }

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${directory.path}/voice-$timestamp.m4a';
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    final recorder = MediaRecorder();

    try {
      await recorder.start(path, audioChannel: RecorderAudioChannel.INPUT);
    } catch (_) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      rethrow;
    }

    _stream = stream;
    _recorder = recorder;
    _path = path;
    _startedAt = DateTime.now();
  }

  Future<RecordedVoiceMessage?> stop() async {
    final recorder = _recorder;
    final path = _path;
    final startedAt = _startedAt;
    if (recorder == null || path == null || startedAt == null) return null;

    _recorder = null;
    _path = null;
    _startedAt = null;
    await recorder.stop();
    await _releaseStream();

    final file = File(path);
    if (!await file.exists()) return null;
    final duration = DateTime.now().difference(startedAt);
    final seconds = duration.inSeconds.clamp(1, 3599);
    return RecordedVoiceMessage(
      path: path,
      fileName: 'voice-message-${seconds}s.m4a',
      sizeBytes: await file.length(),
      duration: duration,
    );
  }

  Future<void> cancel() async {
    final path = _path;
    final recorder = _recorder;
    _recorder = null;
    _path = null;
    _startedAt = null;
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
    }
    await _releaseStream();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> delete(RecordedVoiceMessage recording) async {
    final file = File(recording.path);
    if (await file.exists()) await file.delete();
  }

  Future<void> _releaseStream() async {
    final stream = _stream;
    _stream = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  Future<void> dispose() => cancel();
}
