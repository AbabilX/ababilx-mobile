import 'package:flutter/material.dart';

import 'audio_source_ref.dart';
import 'voice_flat_layout.dart';
import 'voice_playback_controller.dart';

export 'audio_source_ref.dart';

final _voicePlayback = VoicePlaybackController();

class VoiceUrlPlayer extends StatelessWidget {
  const VoiceUrlPlayer({
    super.key,
    required this.source,
    required this.fileName,
    this.compact = false,
    this.flat = false,
    this.trailing,
    this.waveSeed,
  });

  final AudioSourceRef source;
  final String fileName;
  final bool compact;

  /// Inside a chat bubble: no pill of its own (the bubble already is one),
  /// a round play button and a bar that takes the remaining width.
  final bool flat;

  /// Flat only: sits at the end of the clock's line (the bubble's time and
  /// ticks).
  final Widget? trailing;

  /// What the bars are drawn from. Recordings share file names
  /// (`voice-message-34s`), so the caller passes something unique to the note.
  final String? waveSeed;

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
            seed: waveSeed ?? source.id,
            trailing: trailing,
            onToggle: () => _toggle(context),
            // Only the note that is loaded can be moved through; on any
            // other, a tap on the bars stays the bubble's own tap.
            onSeek: selected && _voicePlayback.duration > Duration.zero
                ? _voicePlayback.seek
                : null,
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
