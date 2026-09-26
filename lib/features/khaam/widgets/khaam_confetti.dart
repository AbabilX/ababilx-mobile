import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One burst of confetti, played once from [origin] (fractions of the box).
/// Drawn by hand so JPack adds no package — see the plan's note on
/// `pubspec.yaml` being an Android change.
class JPackConfetti extends StatefulWidget {
  const JPackConfetti({
    super.key,
    required this.colors,
    this.origin = const Alignment(0, -0.2),
    this.count = 120,
    this.duration = const Duration(milliseconds: 2600),
  });

  final List<Color> colors;
  final Alignment origin;
  final int count;
  final Duration duration;

  @override
  State<JPackConfetti> createState() => _JPackConfettiState();
}

class _JPackConfettiState extends State<JPackConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _particles = List.generate(widget.count, (i) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.4;
      final speed = 0.55 + rnd.nextDouble() * 0.9;
      return _Particle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: widget.colors[i % widget.colors.length],
        size: 5 + rnd.nextDouble() * 7,
        spin: (rnd.nextDouble() - 0.5) * 18,
        shape: _Shape.values[rnd.nextInt(_Shape.values.length)],
        wobble: rnd.nextDouble() * math.pi * 2,
      );
    });
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            animation: _controller,
            particles: _particles,
            origin: widget.origin,
          ),
        ),
      ),
    );
  }
}

enum _Shape { rect, circle }

class _Particle {
  const _Particle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.shape,
    required this.wobble,
  });

  final double vx;
  final double vy;
  final Color color;
  final double size;
  final double spin;
  final _Shape shape;
  final double wobble;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.animation,
    required this.particles,
    required this.origin,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Particle> particles;
  final Alignment origin;

  static const _gravity = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    final start = origin.alongSize(size);
    final scale = size.shortestSide;
    // Fade over the last third so the burst settles rather than vanishing.
    final alpha = t < 0.66 ? 1.0 : (1 - (t - 0.66) / 0.34).clamp(0.0, 1.0);
    final paint = Paint();
    for (final p in particles) {
      // Air drag slows the throw; gravity takes over.
      final drag = 1 - math.exp(-3 * t);
      final dx =
          p.vx * drag / 3 * scale * 1.4 + math.sin(p.wobble + t * 12) * 6;
      final dy = (p.vy * drag / 3 + _gravity * t * t) * scale * 1.1;
      final pos = start + Offset(dx, dy);
      if (pos.dy > size.height + 20) continue;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      paint.color = p.color.withValues(alpha: alpha);
      switch (p.shape) {
        case _Shape.rect:
          // A strip turning in 3D reads as its width breathing.
          final w = p.size * (0.35 + 0.65 * math.cos(p.wobble + t * 20).abs());
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: w,
              height: p.size * 0.5,
            ),
            paint,
          );
        case _Shape.circle:
          canvas.drawCircle(Offset.zero, p.size * 0.32, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
