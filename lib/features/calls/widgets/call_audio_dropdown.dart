import 'package:flutter/material.dart';

/// The reference app's drop-down triangle on the audio button: shown when a
/// press opens the output list rather than switching earpiece ↔ speaker. Sits
/// on the lower right of the circle, over the seat's own [child].
class CallAudioDropdown extends StatelessWidget {
  const CallAudioDropdown({
    super.key,
    required this.show,
    required this.diameter,
    required this.child,
  });

  final bool show;
  final double diameter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        child,
        Positioned(
          top: diameter - 20,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Align(
              alignment: const Alignment(0.62, 0),
              child: Icon(
                Icons.arrow_drop_down_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
