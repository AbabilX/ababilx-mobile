import 'dart:ui';

import 'package:flutter/material.dart';

/// True while a bottom-bar tab is held for rearranging.
final ValueNotifier<bool> navReordering = ValueNotifier(false);

/// Blurs and dims everything behind the bar while a tab is being dragged, so
/// the bar is the only sharp thing on screen. It eases in and out, and draws
/// nothing at all while idle (a backdrop blur costs a full-screen pass).
class NavReorderBlur extends StatelessWidget {
  const NavReorderBlur({super.key});

  static const _sigma = 8.0;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: navReordering,
        builder: (context, on, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: on ? 1 : 0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, t, _) {
            if (t == 0) return const SizedBox.shrink();
            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _sigma * t,
                  sigmaY: _sigma * t,
                ),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18 * t),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
