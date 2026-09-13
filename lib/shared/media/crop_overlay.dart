import 'package:flutter/material.dart';

/// Dims everything outside the crop window and draws the frame on top.
///
/// The photo is painted underneath this, full size, so you can see what you
/// are about to cut off — clipping the image to the window made the editor
/// feel like a stamp, not a crop.
class CropOverlayPainter extends CustomPainter {
  const CropOverlayPainter({required this.crop, required this.circle});

  final Rect crop;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = circle ? (Path()..addOval(crop)) : (Path()..addRRect(_frame));

    canvas.drawPath(
      Path()
        ..addRect(Offset.zero & size)
        ..addPath(hole, Offset.zero)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = const Color(0x99000000),
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (circle) {
      canvas.drawOval(crop, border);
      return;
    }

    canvas.drawRRect(_frame, border);
    _thirds(canvas);
    _corners(canvas);
  }

  RRect get _frame => RRect.fromRectAndRadius(crop, const Radius.circular(4));

  void _thirds(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), paint);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), paint);
    }
  }

  void _corners(Canvas canvas) {
    const arm = 18.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    void corner(Offset origin, Offset dx, Offset dy) {
      canvas.drawLine(origin, origin + dx, paint);
      canvas.drawLine(origin, origin + dy, paint);
    }

    corner(crop.topLeft, const Offset(arm, 0), const Offset(0, arm));
    corner(crop.topRight, const Offset(-arm, 0), const Offset(0, arm));
    corner(crop.bottomLeft, const Offset(arm, 0), const Offset(0, -arm));
    corner(crop.bottomRight, const Offset(-arm, 0), const Offset(0, -arm));
  }

  @override
  bool shouldRepaint(CropOverlayPainter old) =>
      old.crop != crop || old.circle != circle;
}
