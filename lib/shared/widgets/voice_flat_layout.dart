import 'package:flutter/material.dart';

import 'voice_waveform.dart';

/// The shape of a voice note inside a chat bubble: a round control on the
/// leading side, the waveform beside it, and one line under the waveform with
/// the clock at its start and [trailing] (the bubble's time and ticks) at its
/// end. No fill of its own — the bubble already is one.
class VoiceRowFrame extends StatelessWidget {
  const VoiceRowFrame({
    super.key,
    required this.leading,
    required this.seed,
    required this.progress,
    required this.label,
    this.trailing,
    this.onSeek,
  });

  /// Height of the whole row, and the side of the round control.
  static const height = 44.0;

  /// Width the timeline reserves for a voice note.
  static const width = 232.0;

  final Widget? leading;
  final String seed;
  final double progress;
  final String label;
  final Widget? trailing;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox.square(dimension: height, child: leading),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Takes what the line under it leaves, so a larger system
                // font shortens the bars instead of overflowing the row.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: VoiceWaveform(
                      seed: seed,
                      progress: progress,
                      color: colors.primary,
                      onSeek: onSeek,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A voice note that can be played: [VoiceRowFrame] with the play button.
class VoiceFlatLayout extends StatelessWidget {
  const VoiceFlatLayout({
    super.key,
    required this.playing,
    required this.progress,
    required this.clock,
    required this.seed,
    required this.onToggle,
    this.onSeek,
    this.trailing,
  });

  final bool playing;
  final double progress;
  final String clock;
  final String seed;
  final VoidCallback onToggle;
  final ValueChanged<double>? onSeek;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return VoiceRowFrame(
      seed: seed,
      progress: progress,
      label: clock,
      trailing: trailing,
      onSeek: onSeek,
      leading: Material(
        color: colors.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 28,
            color: colors.onPrimary,
          ),
        ),
      ),
    );
  }
}

Widget voiceProgressBar(double progress, Color color) => ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: progress,
    minHeight: 4,
    backgroundColor: color.withValues(alpha: 0.22),
    color: color,
  ),
);
