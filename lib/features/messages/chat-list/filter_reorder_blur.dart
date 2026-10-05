import 'dart:ui';

import 'package:flutter/material.dart';

/// True while a filter pill is held for rearranging.
final ValueNotifier<bool> filterReordering = ValueNotifier(false);

/// Blurs [child] while a pill is dragged, so the pills are the only sharp
/// thing on screen. The tree shape never changes (a list under it keeps its
/// scroll position); at rest the filter is switched off and costs nothing.
class FilterReorderBlur extends StatelessWidget {
  const FilterReorderBlur({super.key, required this.child});

  final Widget child;

  static const _sigma = 6.0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: filterReordering,
    child: child,
    builder: (context, on, child) => TweenAnimationBuilder<double>(
      tween: Tween(end: on ? 1 : 0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: child,
      builder: (context, t, child) => ImageFiltered(
        enabled: t > 0,
        imageFilter: ImageFilter.blur(sigmaX: _sigma * t, sigmaY: _sigma * t),
        child: child,
      ),
    ),
  );
}
