import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

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

class MicrophonePermissionException implements Exception {
  const MicrophonePermissionException({this.permanentlyDenied = false});

  final bool permanentlyDenied;
}

/// Native mic recorder for voice messages. Uses the `record` package instead of
/// flutter_webrtc MediaRecorder, which produced empty files for audio-only
/// capture on Android.
class VoiceMessageRecorder {
  final _recorder = AudioRecorder();
  DateTime? _startedAt;

  /// Runs only while the mic is live, so a pause is not counted as audio.
  final _live = Stopwatch();
  String? _path;
  bool _paused = false;

  bool get active => _path != null;
  bool get paused => _paused;

  Future<void> start() async {
    if (active) return;

    // Use the record plugin's native permission flow so Android/iOS show the
    // system dialog. permission_handler.request() here was returning denied
    // without prompting and blocking recording.
    final granted = await _recorder.hasPermission(request: true);
    if (!granted) {
      final status = await Permission.microphone.status;
      throw MicrophonePermissionException(
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${directory.path}/voice-$timestamp.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );

    _path = path;
    _startedAt = DateTime.now();
    _paused = false;
    _live
      ..reset()
      ..start();
  }

  Future<void> pause() async {
    if (!active || _paused) return;
    await _recorder.pause();
    _live.stop();
    _paused = true;
  }

  Future<void> resume() async {
    if (!active || !_paused) return;
    await _recorder.resume();
    _live.start();
    _paused = false;
  }

  Future<RecordedVoiceMessage?> stop() async {
    final path = _path;
    final startedAt = _startedAt;
    if (path == null || startedAt == null) return null;

    _path = null;
    _startedAt = null;
    _paused = false;
    _live.stop();
    final duration = _live.elapsed;

    final stoppedPath = await _recorder.stop();
    final filePath = stoppedPath ?? path;
    final file = File(filePath);
    final sizeBytes = await _waitForFinalizedFile(file);
    if (sizeBytes == 0) return null;

    final seconds = duration.inSeconds.clamp(1, 3599);
    return RecordedVoiceMessage(
      path: filePath,
      fileName: 'voice-message-${seconds}s.m4a',
      sizeBytes: sizeBytes,
      duration: duration,
    );
  }

  Future<int> _waitForFinalizedFile(File file) async {
    var previousSize = 0;
    var stableReads = 0;
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!await file.exists()) continue;
      final size = await file.length();
      if (size > 0 && size == previousSize) {
        stableReads++;
        if (stableReads >= 2) return size;
      } else {
        stableReads = 0;
      }
      previousSize = size;
    }
    return await file.exists() ? await file.length() : 0;
  }

  Future<void> cancel() async {
    _path = null;
    _startedAt = null;
    _paused = false;
    _live
      ..stop()
      ..reset();
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  Future<void> delete(RecordedVoiceMessage recording) async {
    final file = File(recording.path);
    if (await file.exists()) await file.delete();
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
