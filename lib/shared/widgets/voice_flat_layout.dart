import 'package:flutter/material.dart';

/// A voice note inside a chat bubble: round play button, a bar that takes the
/// remaining width, the clock. No fill of its own — the bubble already is one.
class VoiceFlatLayout extends StatelessWidget {
  const VoiceFlatLayout({
    super.key,
    required this.playing,
    required this.progress,
    required this.clock,
    required this.onToggle,
  });

  final bool playing;
  final double progress;
  final String clock;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Material(
          color: colors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onToggle,
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: voiceProgressBar(progress, colors.primary)),
        const SizedBox(width: 10),
        Text(
          clock,
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
      ],
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
