import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

final _voicePlayback = _VoicePlaybackController();

class VoiceUrlPlayer extends StatelessWidget {
  const VoiceUrlPlayer({
    super.key,
    required this.url,
    required this.fileName,
    this.compact = false,
  });

  final String url;
  final String fileName;
  final bool compact;

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
      await _voicePlayback.toggle(url);
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
        final selected = _voicePlayback.url == url;
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: colors.onPrimaryContainer.withValues(
                          alpha: 0.22,
                        ),
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _clock(
                      playing || position > Duration.zero ? position : duration,
                    ),
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
  String? url;
  bool playing = false;
  bool completed = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  Future<void> toggle(String nextUrl) async {
    if (url == nextUrl) {
      if (playing) {
        await _player.pause();
      } else if (completed) {
        completed = false;
        await _player.play(UrlSource(nextUrl));
      } else {
        await _player.resume();
      }
      return;
    }

    await _player.stop();
    url = nextUrl;
    completed = false;
    duration = Duration.zero;
    position = Duration.zero;
    notifyListeners();
    await _player.play(UrlSource(nextUrl));
  }
}
