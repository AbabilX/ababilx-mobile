import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'audio_source_ref.dart';
import 'voice_flat_layout.dart';

export 'audio_source_ref.dart';

final _voicePlayback = _VoicePlaybackController();

class VoiceUrlPlayer extends StatelessWidget {
  const VoiceUrlPlayer({
    super.key,
    required this.source,
    required this.fileName,
    this.compact = false,
    this.flat = false,
  });

  final AudioSourceRef source;
  final String fileName;
  final bool compact;

  /// Inside a chat bubble: no pill of its own (the bubble already is one),
  /// a round play button and a bar that takes the remaining width.
  final bool flat;

  Duration get _namedDuration {
    final match = RegExp(r'voice-message-(\d+)s').firstMatch(fileName);
    return Duration(seconds: int.tryParse(match?.group(1) ?? '') ?? 0);
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggle(BuildContext context) async {
    try {
      await _voicePlayback.toggle(source);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play this voice recording.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _voicePlayback,
      builder: (context, _) {
        final selected = _voicePlayback.sourceId == source.id;
        final playing = selected && _voicePlayback.playing;
        final position = selected ? _voicePlayback.position : Duration.zero;
        final duration = selected && _voicePlayback.duration > Duration.zero
            ? _voicePlayback.duration
            : _namedDuration;
        final progress = duration.inMilliseconds <= 0
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );

        final clock = _clock(
          playing || position > Duration.zero ? position : duration,
        );
        if (flat) {
          return VoiceFlatLayout(
            playing: playing,
            progress: progress,
            clock: clock,
            onToggle: () => _toggle(context),
          );
        }
        return Material(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => _toggle(context),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 12,
                vertical: compact ? 7 : 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: compact ? 72 : 104,
                    child: voiceProgressBar(
                      progress,
                      colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    clock,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoicePlaybackController extends ChangeNotifier {
  _VoicePlaybackController() {
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
}
