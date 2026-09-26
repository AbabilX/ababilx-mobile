import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The card arriving: it rises, straightens from a slight tilt and settles
/// with a small overshoot, as if laid on the table in front of you.
class KhaamCardEntrance extends StatelessWidget {
  const KhaamCardEntrance({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (_, child) {
      final v = animation.value;
      final spring = Curves.easeOutBack.transform(v);
      return Opacity(
        opacity: Curves.easeOut.transform(math.min(1, v * 1.8)),
        child: Transform.translate(
          offset: Offset(0, (1 - spring) * 90),
          child: Transform.rotate(
            angle: (1 - spring) * -0.07,
            child: Transform.scale(scale: 0.86 + 0.14 * spring, child: child),
          ),
        ),
      );
    },
  );
}
