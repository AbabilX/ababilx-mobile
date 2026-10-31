import 'package:flutter/material.dart';

/// The dimming behind the long-press menu.
///
/// The reference app's shade is there in full from the first frame and only
/// fades on the way out ([fadeOut]). No blur: a full-screen blur whose sigma
/// changes every frame was the costliest thing this overlay drew.
class MessageMenuShade extends StatelessWidget {
  const MessageMenuShade({
    super.key,
    required this.route,
    required this.fadeOut,
  });

  final Animation<double> route;
  final Animation<double> fadeOut;

  @override
  Widget build(BuildContext context) {
    final shade = Theme.of(context).colorScheme.scrim.withValues(alpha: 0.56);
    return AnimatedBuilder(
      animation: route,
      builder: (context, _) => ColoredBox(
        color: shade.withValues(
          alpha:
              shade.a *
              (route.status == AnimationStatus.reverse ? fadeOut.value : 1.0),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
