import 'dart:ui';

import 'package:flutter/material.dart';

import 'shell_pill_metrics.dart';

/// Frosted floating pill chrome — content scrolls under for depth.
class ShellPillChrome extends StatelessWidget {
  const ShellPillChrome({
    super.key,
    required this.child,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  final Widget child;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ??
        (shape == BoxShape.circle
            ? null
            : BorderRadius.circular(ShellPillMetrics.height / 2));
    final fill = scheme.surfaceContainerHigh.withValues(
      alpha: scheme.brightness == Brightness.dark ? 0.72 : 0.78,
    );

    return Container(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : radius,
        boxShadow: shellPillShadow(scheme),
      ),
      child: ClipRRect(
        borderRadius: shape == BoxShape.circle
            ? BorderRadius.circular(ShellPillMetrics.height / 2)
            : (radius ?? BorderRadius.zero),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              shape: shape,
              borderRadius: shape == BoxShape.circle ? null : radius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

List<BoxShadow> shellPillShadow(ColorScheme scheme) => [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.12,
        ),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
