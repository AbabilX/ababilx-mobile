import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/jpack_covers.dart';

/// A JPack envelope is 1 : 1.6, like the red packets it is modelled on.
const jpackCoverAspect = 1 / 1.6;

/// Where the upper panel meets the flap, as a fraction of the height: the
/// edges sit at [_flapEdge] and the curve dips to [_flapDip] in the middle,
/// which puts its lowest point — and the seal — at 0.75.
const _flapEdge = 0.66;
const _flapDip = 0.84;

/// Centre of the seal on a cover of [size].
Offset jpackSealCenter(Size size) => Offset(size.width / 2, size.height * 0.75);

double jpackSealRadius(Size size) => size.width * 0.17;

/// Everything above the flap's curve.
Path jpackUpperPath(Size size) => Path()
  ..moveTo(0, 0)
  ..lineTo(size.width, 0)
  ..lineTo(size.width, size.height * _flapEdge)
  ..quadraticBezierTo(
    size.width / 2,
    size.height * _flapDip,
    0,
    size.height * _flapEdge,
  )
  ..close();

/// The flap: the curve and everything below it.
Path jpackLowerPath(Size size) => Path()
  ..moveTo(0, size.height * _flapEdge)
  ..quadraticBezierTo(
    size.width / 2,
    size.height * _flapDip,
    size.width,
    size.height * _flapEdge,
  )
  ..lineTo(size.width, size.height)
  ..lineTo(0, size.height)
  ..close();

enum JPackCoverPart { full, upper, lower }

/// One cover, drawn. The gallery, the chat card and the open screen all use
/// this, so a cover looks the same everywhere it appears.
class JPackCoverArt extends StatelessWidget {
  const JPackCoverArt({
    super.key,
    required this.cover,
    required this.width,
    this.part = JPackCoverPart.full,
    this.showSeal = true,
    this.sealLabel = '৳',
    this.radius,
    this.child,
  });

  final JPackCover cover;
  final double width;
  final JPackCoverPart part;
  final bool showSeal;
  final String sealLabel;
  final double? radius;

  /// Drawn over the upper panel (message, sender) — the art stays behind it.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final size = Size(width, width / jpackCoverAspect);
    final r = radius ?? width * 0.06;
    final center = jpackSealCenter(size);
    final sealR = jpackSealRadius(size);
    return SizedBox.fromSize(
      size: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: JPackCoverPainter(cover: cover, part: part),
              ),
            ),
            if (child != null && part != JPackCoverPart.lower)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: size.height * _flapEdge,
                child: child!,
              ),
            if (showSeal && part != JPackCoverPart.upper)
              Positioned(
                left: center.dx - sealR,
                top: center.dy - sealR,
                width: sealR * 2,
                height: sealR * 2,
                child: JPackSeal(cover: cover, label: sealLabel),
              ),
          ],
        ),
      ),
    );
  }
}

/// The round gold button on the flap — WeChat's 開, ours says ৳ or "খুলুন".
class JPackSeal extends StatelessWidget {
  const JPackSeal({super.key, required this.cover, required this.label});

  final JPackCover cover;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final d = box.biggest.shortestSide;
        final ink = Color.lerp(cover.flap, Colors.black, 0.25)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.35),
              colors: [
                Color.lerp(cover.accent, Colors.white, 0.45)!,
                cover.accent,
                Color.lerp(cover.accent, Colors.black, 0.12)!,
              ],
              stops: const [0, 0.6, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: d * 0.18,
                offset: Offset(0, d * 0.06),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(d * 0.12),
              child: FittedBox(
                child: Text(
                  label,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: d * 0.42,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class JPackCoverPainter extends CustomPainter {
  JPackCoverPainter({required this.cover, this.part = JPackCoverPart.full});

  final JPackCover cover;
  final JPackCoverPart part;

  @override
  void paint(Canvas canvas, Size size) {
    if (part != JPackCoverPart.lower) {
      canvas.save();
      canvas.clipPath(jpackUpperPath(size));
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cover.top, cover.bottom],
          ).createShader(rect),
      );
      final upper = Rect.fromLTWH(0, 0, size.width, size.height * _flapDip);
      _paintMotif(canvas, upper, size.width);
      canvas.restore();
    }
    if (part != JPackCoverPart.upper) {
      final lower = jpackLowerPath(size);
      // A soft shadow along the curve lifts the flap off the panel.
      canvas.drawPath(
        lower.shift(Offset(0, -size.width * 0.012)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.02),
      );
      final flapRect = Rect.fromLTWH(
        0,
        size.height * _flapEdge,
        size.width,
        size.height * (1 - _flapEdge),
      );
      canvas.drawPath(
        lower,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(cover.flap, Colors.white, 0.06)!, cover.flap],
          ).createShader(flapRect),
      );
    }
  }

  void _paintMotif(Canvas canvas, Rect r, double w) {
    switch (cover.motif) {
      case CoverMotif.classic:
        _classic(canvas, r, w);
      case CoverMotif.eid:
        _eid(canvas, r, w);
      case CoverMotif.boishakh:
        _boishakh(canvas, r, w);
      case CoverMotif.birthday:
        _birthday(canvas, r, w);
      case CoverMotif.wedding:
        _wedding(canvas, r, w);
      case CoverMotif.congrats:
        _congrats(canvas, r, w);
      case CoverMotif.thanks:
        _thanks(canvas, r, w);
      case CoverMotif.victory:
        _victory(canvas, r, w);
    }
  }

  Paint _fill(Color c, [double alpha = 1]) =>
      Paint()..color = c.withValues(alpha: alpha);

  Paint _stroke(Color c, double width, [double alpha = 1]) => Paint()
    ..color = c.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  // ── classic: gold lattice and a few coins ────────────────────────────────
  void _classic(Canvas canvas, Rect r, double w) {
    final step = w / 6;
    final lattice = _stroke(cover.accent, w * 0.006, 0.28);
    for (var x = -r.height; x < r.width + r.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + r.height, r.height), lattice);
      canvas.drawLine(Offset(x, r.height), Offset(x + r.height, 0), lattice);
    }
    final coins = [(0.22, 0.2, 0.09), (0.74, 0.32, 0.12), (0.36, 0.5, 0.07)];
    for (final (cx, cy, cr) in coins) {
      final c = Offset(r.width * cx, r.height * cy);
      canvas.drawCircle(c, w * cr, _fill(cover.accent, 0.9));
      canvas.drawCircle(c, w * cr * 0.72, _stroke(cover.bottom, w * 0.01, 0.5));
      _text(canvas, '৳', c, w * cr * 1.1, cover.bottom.withValues(alpha: 0.7));
    }
  }

  // ── eid: crescent, stars, hanging lanterns ───────────────────────────────
  void _eid(Canvas canvas, Rect r, double w) {
    final moonC = Offset(r.width * 0.7, r.height * 0.26);
    final moonR = w * 0.17;
    final moon = Path()..addOval(Rect.fromCircle(center: moonC, radius: moonR));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: moonC + Offset(moonR * 0.45, -moonR * 0.2),
          radius: moonR * 0.85,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, moon, bite),
      _fill(cover.accent),
    );
    _star(
      canvas,
      moonC + Offset(moonR * 0.55, moonR * 0.1),
      w * 0.035,
      _fill(cover.accent),
    );
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final p = Offset(
        rnd.nextDouble() * r.width,
        rnd.nextDouble() * r.height * 0.8,
      );
      canvas.drawCircle(
        p,
        w * (0.006 + rnd.nextDouble() * 0.008),
        _fill(cover.accent, 0.4 + rnd.nextDouble() * 0.5),
      );
    }
    for (final (x, len) in [(0.16, 0.28), (0.32, 0.18)]) {
      final top = Offset(r.width * x, 0);
      final hang = Offset(r.width * x, r.height * len);
      canvas.drawLine(top, hang, _stroke(cover.accent, w * 0.005, 0.8));
      _lantern(canvas, hang, w * 0.075);
    }
  }

  void _lantern(Canvas canvas, Offset top, double s) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(top.dx - s / 2, top.dy + s * 0.25, s, s * 1.3),
      Radius.circular(s * 0.35),
    );
    canvas.drawRect(
      Rect.fromLTWH(top.dx - s * 0.3, top.dy, s * 0.6, s * 0.25),
      _fill(cover.accent),
    );
    canvas.drawRRect(body, _fill(cover.accent, 0.9));
    canvas.drawRRect(body.deflate(s * 0.14), _fill(cover.bottom, 0.55));
    canvas.drawCircle(body.center, s * 0.14, _fill(const Color(0xFFFFE9A8)));
  }

  // ── boishakh: alpona rosette and a triangle border ───────────────────────
  void _boishakh(Canvas canvas, Rect r, double w) {
    final red = cover.flap;
    final tri = w / 10;
    for (var i = 0; i < 10; i++) {
      final path = Path()
        ..moveTo(i * tri, 0)
        ..lineTo(i * tri + tri, 0)
        ..lineTo(i * tri + tri / 2, tri * 0.8)
        ..close();
      canvas.drawPath(path, _fill(i.isEven ? red : cover.accent, 0.9));
    }
    final c = Offset(r.width / 2, r.height * 0.42);
    canvas.drawCircle(c, w * 0.3, _stroke(red, w * 0.012, 0.9));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -w * 0.19),
          width: w * 0.07,
          height: w * 0.17,
        ),
        _fill(i.isEven ? red : const Color(0xFFF08A24), 0.9),
      );
      canvas.drawCircle(Offset(0, -w * 0.3), w * 0.018, _fill(red));
      canvas.restore();
    }
    canvas.drawCircle(c, w * 0.09, _fill(cover.accent));
    canvas.drawCircle(c, w * 0.05, _fill(red));
    canvas.drawCircle(c, w * 0.018, _fill(Colors.white));
  }

  // ── birthday: balloons and sprinkles ─────────────────────────────────────
  void _birthday(Canvas canvas, Rect r, double w) {
    final rnd = math.Random(3);
    const sprinkle = [
      Color(0xFFFFE08A),
      Color(0xFF8FF0FF),
      Colors.white,
      Color(0xFFFFB3C7),
    ];
    for (var i = 0; i < 26; i++) {
      final p = Offset(
        rnd.nextDouble() * r.width,
        rnd.nextDouble() * r.height * 0.85,
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(rnd.nextDouble() * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: w * 0.035,
            height: w * 0.012,
          ),
          Radius.circular(w * 0.006),
        ),
        _fill(sprinkle[i % sprinkle.length], 0.85),
      );
      canvas.restore();
    }
    final balloons = [
      (0.26, 0.3, const Color(0xFFFFD166)),
      (0.5, 0.2, const Color(0xFFFF5D8F)),
      (0.74, 0.32, const Color(0xFF5CE1E6)),
    ];
    for (final (x, y, color) in balloons) {
      final c = Offset(r.width * x, r.height * y);
      final bw = w * 0.2;
      final oval = Rect.fromCenter(center: c, width: bw, height: bw * 1.2);
      final string = Path()
        ..moveTo(c.dx, oval.bottom)
        ..quadraticBezierTo(
          c.dx - bw * 0.2,
          oval.bottom + bw * 0.5,
          c.dx + bw * 0.05,
          oval.bottom + bw * 1.1,
        );
      canvas.drawPath(string, _stroke(Colors.white, w * 0.005, 0.8));
      canvas.drawOval(oval, _fill(color));
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(-bw * 0.2, -bw * 0.25),
          width: bw * 0.18,
          height: bw * 0.3,
        ),
        _fill(Colors.white, 0.45),
      );
    }
  }

  // ── wedding: arches and a mehndi mandala ─────────────────────────────────
  void _wedding(Canvas canvas, Rect r, double w) {
    final gold = cover.accent;
    final arch = w / 5;
    for (var i = 0; i < 5; i++) {
      final left = i * arch;
      final path = Path()
        ..moveTo(left + arch * 0.1, arch * 1.1)
        ..lineTo(left + arch * 0.1, arch * 0.55)
        ..quadraticBezierTo(left + arch * 0.1, arch * 0.12, left + arch / 2, 0)
        ..quadraticBezierTo(
          left + arch * 0.9,
          arch * 0.12,
          left + arch * 0.9,
          arch * 0.55,
        )
        ..lineTo(left + arch * 0.9, arch * 1.1);
      canvas.drawPath(path, _stroke(gold, w * 0.006, 0.55));
    }
    final c = Offset(r.width / 2, r.height * 0.46);
    for (var ring = 0; ring < 3; ring++) {
      final rad = w * (0.1 + ring * 0.07);
      final count = 8 + ring * 4;
      for (var i = 0; i < count; i++) {
        final a = i * 2 * math.pi / count;
        final p = c + Offset(math.cos(a), math.sin(a)) * rad;
        canvas.drawCircle(
          p,
          w * (0.016 - ring * 0.003),
          _fill(gold, 0.9 - ring * 0.2),
        );
      }
      canvas.drawCircle(c, rad - w * 0.035, _stroke(gold, w * 0.004, 0.5));
    }
    _star(canvas, c, w * 0.05, _fill(gold));
  }

  // ── congrats: stars, sparkles and ribbons ────────────────────────────────
  void _congrats(Canvas canvas, Rect r, double w) {
    final rnd = math.Random(11);
    for (var i = 0; i < 6; i++) {
      final y = r.height * (0.1 + i * 0.12);
      final path = Path()..moveTo(-w * 0.1, y);
      for (var k = 0; k < 6; k++) {
        path.relativeQuadraticBezierTo(
          w * 0.1,
          (k.isEven ? -1 : 1) * w * 0.06,
          w * 0.2,
          0,
        );
      }
      canvas.drawPath(path, _stroke(Colors.white, w * 0.006, 0.12));
    }
    for (var i = 0; i < 9; i++) {
      final p = Offset(
        r.width * (0.1 + rnd.nextDouble() * 0.8),
        r.height * (0.08 + rnd.nextDouble() * 0.6),
      );
      if (i.isEven) {
        _star(
          canvas,
          p,
          w * (0.03 + rnd.nextDouble() * 0.04),
          _fill(cover.accent, 0.95),
        );
      } else {
        _sparkle(
          canvas,
          p,
          w * (0.025 + rnd.nextDouble() * 0.03),
          _fill(Colors.white, 0.9),
        );
      }
    }
  }

  // ── thanks: hearts and leaves ────────────────────────────────────────────
  void _thanks(Canvas canvas, Rect r, double w) {
    final rnd = math.Random(5);
    for (var i = 0; i < 10; i++) {
      final p = Offset(
        r.width * (0.08 + rnd.nextDouble() * 0.84),
        r.height * (0.06 + rnd.nextDouble() * 0.62),
      );
      final s = w * (0.04 + rnd.nextDouble() * 0.05);
      if (i % 3 == 0) {
        _heart(canvas, p, s, _fill(cover.accent, 0.95));
      } else {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(rnd.nextDouble() * math.pi);
        final leaf = Path()
          ..moveTo(0, -s)
          ..quadraticBezierTo(s * 0.7, 0, 0, s)
          ..quadraticBezierTo(-s * 0.7, 0, 0, -s);
        canvas.drawPath(leaf, _fill(Colors.white, 0.22));
        canvas.drawLine(
          Offset(0, -s),
          Offset(0, s),
          _stroke(Colors.white, w * 0.004, 0.3),
        );
        canvas.restore();
      }
    }
    _heart(
      canvas,
      Offset(r.width / 2, r.height * 0.4),
      w * 0.16,
      _fill(cover.accent),
    );
  }

  // ── victory: the red sun on green, with rays ─────────────────────────────
  void _victory(Canvas canvas, Rect r, double w) {
    final c = Offset(r.width * 0.46, r.height * 0.38);
    final rays = _stroke(Colors.white, w * 0.006, 0.14);
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * w * 0.28, c + dir * w * 0.9, rays);
    }
    canvas.drawCircle(c, w * 0.22, _fill(cover.accent));
    final rnd = math.Random(9);
    for (var i = 0; i < 7; i++) {
      _star(
        canvas,
        Offset(rnd.nextDouble() * r.width, rnd.nextDouble() * r.height * 0.75),
        w * (0.015 + rnd.nextDouble() * 0.02),
        _fill(Colors.white, 0.7),
      );
    }
  }

  void _star(Canvas canvas, Offset c, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? radius : radius * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  void _sparkle(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s);
    canvas.drawPath(path, paint);
  }

  void _heart(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.55)
      ..cubicTo(
        c.dx - s * 1.1,
        c.dy - s * 0.1,
        c.dx - s * 0.55,
        c.dy - s * 0.85,
        c.dx,
        c.dy - s * 0.3,
      )
      ..cubicTo(
        c.dx + s * 0.55,
        c.dy - s * 0.85,
        c.dx + s * 1.1,
        c.dy - s * 0.1,
        c.dx,
        c.dy + s * 0.55,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(JPackCoverPainter old) =>
      old.cover.id != cover.id || old.part != part;
}
