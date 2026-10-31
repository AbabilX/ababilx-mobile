import 'package:flutter/material.dart';

/// How far the highlight has moved at [progress] (0..1) across [width]: it
/// starts one width before the child and ends one width past it.
double shimmerSweepDx(double progress, double width) =>
    width * (2 * progress - 1);

/// Sweeps a highlight across [child] while [active]. Otherwise draws [child]
/// untouched, with no ticker running. Under reduced motion it dims instead.
class ShimmerMask extends StatefulWidget {
  const ShimmerMask({super.key, required this.active, required this.child});

  static const period = Duration(milliseconds: 1600);

  final bool active;
  final Widget child;

  @override
  State<ShimmerMask> createState() => _ShimmerMaskState();
}

class _ShimmerMaskState extends State<ShimmerMask>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: ShimmerMask.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ShimmerMask oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (run && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (!run && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Opacity(opacity: 0.55, child: widget.child);
    }
    final ink = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _sweep,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: [ink.withValues(alpha: 0.4), ink, ink.withValues(alpha: 0.4)],
          stops: const [0.3, 0.5, 0.7],
          transform: _Slide(shimmerSweepDx(_sweep.value, bounds.width)),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
