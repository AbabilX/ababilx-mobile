import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'signal_menu_metrics.dart';

/// A light blur over the conversation behind the long-press menu, so the
/// redrawn message and its actions read as lifted off the timeline rather
/// than pasted on top of it.
///
/// The blur rises with the reveal and falls with the dismissal. The scrim the
/// dialog barrier draws still sits underneath, so the dimming is unchanged.
class SignalMenuBackdrop extends StatelessWidget {
  const SignalMenuBackdrop({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final sigma = SignalMenuMetrics.backdropBlur * animation.value;
        // A zero-sigma BackdropFilter still costs a full-screen layer.
        if (sigma < 0.1) return const SizedBox.expand();
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
