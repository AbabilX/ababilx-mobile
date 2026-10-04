import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_source_ref.dart';

/// The one player every voice note shares: starting a note stops the last.
class VoicePlaybackController extends ChangeNotifier {
  VoicePlaybackController() {
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen((state) {
        playing = state == PlayerState.playing;
        notifyListeners();
      }),
      _player.onDurationChanged.listen((value) {
        duration = value;
        notifyListeners();
      }),
      _player.onPositionChanged.listen((value) {
        position = value;
        notifyListeners();
      }),
      _player.onPlayerComplete.listen((_) {
        playing = false;
        completed = true;
        position = Duration.zero;
        notifyListeners();
      }),
    ]);
  }

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? sourceId;
  bool playing = false;
  bool completed = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  Future<void> toggle(AudioSourceRef next) async {
    if (sourceId == next.id) {
      if (playing) {
        await _player.pause();
      } else if (completed) {
        completed = false;
        await _player.play(next.source);
      } else {
        await _player.resume();
      }
      return;
    }

    await _player.stop();
    sourceId = next.id;
    completed = false;
    duration = Duration.zero;
    position = Duration.zero;
    notifyListeners();
    await _player.play(next.source);
  }

  Future<void> seek(double fraction) async {
    if (duration <= Duration.zero) return;
    final target = duration * fraction.clamp(0.0, 1.0);
    completed = false;
    position = target;
    notifyListeners();
    await _player.seek(target);
  }
}
