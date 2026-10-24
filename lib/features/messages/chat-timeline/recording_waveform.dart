import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bars across the recording sheet. Moving while the mic is live, frozen at
/// rest heights while paused, so the two states read apart at a glance.
class RecordingWaveformPainter extends CustomPainter {
  RecordingWaveformPainter({
    required this.progress,
    required this.paused,
    required this.color,
  });

  final double progress;
  final bool paused;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / 5).floor().clamp(24, 56);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    final midY = size.height / 2;
    final gap = size.width / barCount;
    final t = progress * math.pi * 2;
    for (var i = 0; i < barCount; i++) {
      final pulse = paused
          ? 0.2 + (i % 5) * 0.06
          : (math.sin(t + i * 0.42) + 1) / 2;
      final h = 4.0 + pulse * (size.height * 0.72);
      final x = gap * i + gap / 2;
      canvas.drawLine(Offset(x, midY - h / 2), Offset(x, midY + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant RecordingWaveformPainter old) =>
      old.progress != progress || old.paused != paused || old.color != color;
}

/// Dashed ring behind the view-once "1".
class DottedCirclePainter extends CustomPainter {
  DottedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    const dashCount = 18;
    const dashSweep = math.pi * 2 / dashCount * 0.45;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * math.pi * 2 / dashCount,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DottedCirclePainter old) => old.color != color;
}
