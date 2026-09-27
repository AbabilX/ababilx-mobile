import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/khaam_covers.dart';
import 'khaam_foil_painter.dart';
import '../../../shared/text/latin_tracking.dart';

/// Foil over [child] that a finger scratches away.
///
/// Coverage is counted on a coarse grid rather than by reading pixels back:
/// a cell is gone once the brush has passed over its centre. Past
/// [threshold] the card counts as opened ([onScratchedEnough], once); the
/// parent then sets [cleared] and the rest of the foil lifts off.
class KhaamScratchFoil extends StatefulWidget {
  const KhaamScratchFoil({
    super.key,
    required this.cover,
    required this.hint,
    required this.cleared,
    required this.onScratchedEnough,
    required this.child,
    this.threshold = 0.45,
    this.radius = 16,
  });

  final KhaamCover cover;
  final String hint;
  final bool cleared;
  final VoidCallback onScratchedEnough;
  final Widget child;
  final double threshold;
  final double radius;

  @override
  State<KhaamScratchFoil> createState() => _KhaamScratchFoilState();
}

class _KhaamScratchFoilState extends State<KhaamScratchFoil>
    with TickerProviderStateMixin {
  static const _cols = 18;
  static const _rows = 8;

  final _strokes = KhaamScratchStrokes();
  final _cells = List<bool>.filled(_cols * _rows, false);
  int _hit = 0;
  int _lastTick = 0;
  bool _fired = false;
  Offset? _last;

  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: widget.cleared ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.cleared) _sheen.repeat();
  }

  @override
  void didUpdateWidget(KhaamScratchFoil old) {
    super.didUpdateWidget(old);
    if (widget.cleared && !old.cleared) {
      _sheen.stop();
      _lift.forward();
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    _lift.dispose();
    _strokes.dispose();
    super.dispose();
  }

  double _brush(Size size) => math.max(30, size.shortestSide * 0.3);

  void _scratch(Offset p, Size size, {bool start = false}) {
    if (widget.cleared) return;
    _strokes.add(p, start: start);
    // Walk the segment so a fast swipe counts every cell it crossed.
    final from = start ? p : (_last ?? p);
    final r = _brush(size) / 2;
    final steps = math.max(1, ((p - from).distance / (r / 2)).ceil());
    for (var i = 0; i <= steps; i++) {
      _mark(Offset.lerp(from, p, i / steps)!, r, size);
    }
    _last = p;
    if (_hit - _lastTick >= 5) {
      _lastTick = _hit;
      HapticFeedback.selectionClick();
    }
    if (!_fired && _hit / _cells.length >= widget.threshold) {
      _fired = true;
      widget.onScratchedEnough();
    }
  }

  void _mark(Offset p, double r, Size size) {
    final cw = size.width / _cols;
    final ch = size.height / _rows;
    final c0 = ((p.dx - r) / cw).floor().clamp(0, _cols - 1);
    final c1 = ((p.dx + r) / cw).floor().clamp(0, _cols - 1);
    final r0 = ((p.dy - r) / ch).floor().clamp(0, _rows - 1);
    final r1 = ((p.dy + r) / ch).floor().clamp(0, _rows - 1);
    for (var row = r0; row <= r1; row++) {
      for (var col = c0; col <= c1; col++) {
        final i = row * _cols + col;
        if (_cells[i]) continue;
        final centre = Offset((col + 0.5) * cw, (row + 0.5) * ch);
        if ((centre - p).distance <= r) {
          _cells[i] = true;
          _hit++;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Color.lerp(widget.cover.accent, Colors.black, 0.62),
      fontWeight: FontWeight.w800,
      letterSpacing: latinTracking(widget.hint, 0.3),
    );
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: widget.cleared,
            child: LayoutBuilder(
              builder: (context, box) {
                final size = box.biggest;
                return AnimatedBuilder(
                  animation: _lift,
                  builder: (_, child) => Opacity(
                    opacity: 1 - Curves.easeIn.transform(_lift.value),
                    child: Transform.scale(
                      scale: 1 + _lift.value * 0.08,
                      child: child,
                    ),
                  ),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) =>
                        _scratch(e.localPosition, size, start: true),
                    onPointerMove: (e) => _scratch(e.localPosition, size),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: size,
                        painter: KhaamFoilPainter(
                          cover: widget.cover,
                          hint: widget.hint,
                          hintStyle: hintStyle,
                          textDirection: Directionality.of(context),
                          sheen: _sheen,
                          strokes: _strokes,
                          brush: _brush(size),
                          radius: widget.radius,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
