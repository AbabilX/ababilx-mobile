import 'package:flutter/material.dart';

/// The bar strip of a voice note. The played part takes [color], the rest a
/// faded copy of it.
///
/// The heights are NOT read from the audio: nothing stores a recording's
/// amplitudes, and decoding every voice note on screen to get them would cost
/// more than the picture is worth. They are derived from [seed] instead, so a
/// given note always draws the same shape, on every phone.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.seed,
    required this.progress,
    required this.color,
    this.onSeek,
  });

  final String seed;
  final double progress;
  final Color color;

  /// Tap position as a 0–1 fraction of the strip. Null leaves the tap to
  /// whatever is underneath.
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final paint = LayoutBuilder(
      builder: (context, box) => CustomPaint(
        size: Size(box.maxWidth, box.maxHeight),
        painter: _WaveformPainter(
          seed: _hash(seed),
          progress: progress.clamp(0.0, 1.0),
          color: color,
          rtl: rtl,
        ),
      ),
    );
    final seek = onSeek;
    if (seek == null) return paint;
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (box.maxWidth <= 0) return;
          final at = (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
          seek(rtl ? 1 - at : at);
        },
        child: paint,
      ),
    );
  }
}

/// FNV-1a. `String.hashCode` is not promised to be the same on every run.
int _hash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// A 0–1 value for bar [index], stable for a given [seed].
double _noise(int seed, int index) {
  var x = (seed ^ (index * 0x9e3779b1)) & 0xffffffff;
  x = ((x ^ (x >> 15)) * 0x2c1b3c6d) & 0xffffffff;
  x = ((x ^ (x >> 12)) * 0x297a2d39) & 0xffffffff;
  x = x ^ (x >> 15);
  return (x & 0xffff) / 0xffff;
}

/// Speech comes in bursts with quiet between them: a slow envelope decides
/// whether a stretch is loud at all, a fast one gives each bar its own height.
double voiceBarHeight(int seed, int index) {
  final envelope = _noise(seed, index ~/ 5);
  final burst = envelope < 0.35 ? 0.0 : (envelope - 0.35) / 0.65;
  return (0.12 + 0.88 * burst * (0.35 + 0.65 * _noise(seed ^ 0x5bd1, index)))
      .clamp(0.12, 1.0);
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.color,
    required this.rtl,
  });

  final int seed;
  final double progress;
  final Color color;
  final bool rtl;

  static const _bar = 2.5;
  static const _gap = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width + _gap) ~/ (_bar + _gap);
    if (count <= 0 || size.height <= 0) return;
    final played = Paint()..color = color;
    final rest = Paint()..color = color.withValues(alpha: 0.32);
    final reached = progress * count;
    for (var i = 0; i < count; i++) {
      final height = (voiceBarHeight(seed, i) * size.height).clamp(
        2.0,
        size.height,
      );
      final start = i * (_bar + _gap);
      final left = rtl ? size.width - start - _bar : start;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          // Bars stand on the baseline, as Telegram's do.
          Rect.fromLTWH(left, size.height - height, _bar, height),
          const Radius.circular(1),
        ),
        i < reached ? played : rest,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.seed != seed ||
      old.progress != progress ||
      old.color != color ||
      old.rtl != rtl;
}
