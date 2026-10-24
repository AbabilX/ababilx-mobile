import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'recording_waveform.dart';

/// m:ss, in Bangla digits when the app is in Bangla. Capped at 59:59.
String recordingClock(Duration elapsed, {required bool bengali}) {
  final total = elapsed.inSeconds.clamp(0, 3599);
  final raw = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  if (!bengali) return raw;
  const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return raw.split('').map((c) {
    final i = int.tryParse(c);
    return i == null ? c : bn[i];
  }).join();
}

/// Left of the timer: a red dot that blinks with the wave while the mic is
/// live, a pause glyph while paused.
class RecordingStatusDot extends StatelessWidget {
  const RecordingStatusDot({
    super.key,
    required this.wave,
    required this.live,
    required this.paused,
  });

  final Animation<double> wave;
  final bool live;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (paused) {
      return ChatIcon(
        HugeIcons.strokeRoundedPause,
        size: 16,
        strokeWidth: 1.8,
        color: colors.onSurfaceVariant,
      );
    }
    return AnimatedBuilder(
      animation: wave,
      builder: (context, child) => Opacity(
        opacity: live ? 0.35 + 0.65 * (1 - (wave.value * 2 - 1).abs()) : 1,
        child: child,
      ),
      child: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle),
      ),
    );
  }
}

/// Between the timer and view-once: the waveform, a "Paused" capsule over
/// frozen bars, or [note] ("Starting…", "Sending…") instead of either.
class RecordingMiddleStrip extends StatelessWidget {
  const RecordingMiddleStrip({
    super.key,
    required this.wave,
    required this.paused,
    required this.note,
    required this.pausedLabel,
  });

  final Animation<double> wave;
  final bool paused;
  final String? note;
  final String pausedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final note = this.note;
    if (note != null) {
      return SizedBox(
        height: 36,
        child: Center(
          child: Text(
            note,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: wave,
            builder: (context, _) => CustomPaint(
              painter: RecordingWaveformPainter(
                progress: wave.value,
                paused: paused,
                color: paused ? colors.outlineVariant : colors.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (paused)
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.surfaceContainerHighest,
                shape: const StadiumBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  pausedLabel,
                  style: text.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
