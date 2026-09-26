import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/khaam_covers.dart';

/// Where the finger has been. One path, drawn as a thick round stroke that
/// clears the foil under it.
class KhaamScratchStrokes extends ChangeNotifier {
  final path = Path();

  void add(Offset p, {bool start = false}) {
    if (start) {
      // A tiny segment so a single tap already clears a round dot.
      path
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + 0.1, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
    notifyListeners();
  }
}

/// The metallic foil in the cover's own accent: brushed lines, a scatter of
/// glints, a light band sweeping across it and the hint printed on the foil
/// itself, so the hint is scratched away with everything else.
class KhaamFoilPainter extends CustomPainter {
  KhaamFoilPainter({
    required this.cover,
    required this.hint,
    required this.hintStyle,
    required this.textDirection,
    required this.sheen,
    this.strokes,
    this.brush = 0,
    this.radius = 16,
  }) : super(repaint: Listenable.merge([sheen, strokes]));

  final KhaamCover cover;
  final String hint;
  final TextStyle? hintStyle;
  final TextDirection textDirection;

  /// 0 → 1 across the card, looping on the open screen, still in a bubble.
  final Animation<double> sheen;
  final KhaamScratchStrokes? strokes;
  final double brush;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    final light = Color.lerp(cover.accent, Colors.white, 0.5)!;
    final dark = Color.lerp(cover.accent, Colors.black, 0.25)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [dark, light, cover.accent, light, dark],
          stops: const [0, 0.28, 0.5, 0.72, 1],
        ).createShader(rect),
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (var y = 1.5; y < size.height; y += 3.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final rnd = math.Random(11);
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    final count = (size.width * size.height / 700).clamp(8, 160).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.5 + rnd.nextDouble(),
        glint,
      );
    }

    final band = math.max(size.width * 0.45, 60.0);
    final x = -band + (size.width + band) * sheen.value;
    final bandRect = Rect.fromLTWH(x, 0, band, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(bandRect),
    );

    final tp = TextPainter(
      text: TextSpan(text: hint, style: hintStyle),
      textAlign: TextAlign.center,
      textDirection: textDirection,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, size.width - 24));
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );

    final path = strokes?.path;
    if (path != null && brush > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = brush
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KhaamFoilPainter old) =>
      old.cover != cover ||
      old.hint != hint ||
      old.brush != brush ||
      old.strokes != strokes ||
      old.hintStyle != hintStyle;
}

/// The foil as a still strip — the unopened bubble's "scratch me" promise.
class KhaamFoilStrip extends StatelessWidget {
  const KhaamFoilStrip({
    super.key,
    required this.cover,
    required this.hint,
    this.height = 40,
  });

  final KhaamCover cover;
  final String hint;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Color.lerp(cover.accent, Colors.black, 0.62),
      fontWeight: FontWeight.w700,
    );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: KhaamFoilPainter(
          cover: cover,
          hint: hint,
          hintStyle: style,
          textDirection: Directionality.of(context),
          sheen: const AlwaysStoppedAnimation(0.3),
          radius: 10,
        ),
      ),
    );
  }
}
