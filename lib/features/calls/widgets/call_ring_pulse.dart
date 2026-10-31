import 'package:flutter/material.dart';

/// Expanding rings behind a ringing caller's avatar.
///
/// The reference app's incoming screen keeps one moving element while the phone
/// rings, so a call that is still alive never looks like a frozen screenshot.
class CallRingPulse extends StatefulWidget {
  const CallRingPulse({super.key, required this.size, required this.child});

  /// Diameter of [child]; the rings are drawn outside it.
  final double size;
  final Widget child;

  @override
  State<CallRingPulse> createState() => _CallRingPulseState();
}

class _CallRingPulseState extends State<CallRingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outer = widget.size * 1.6;
    return SizedBox(
      width: outer,
      height: outer,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            // Two rings, half a cycle apart, so one is always mid-flight.
            for (final offset in const [0.0, 0.5])
              _ring((_controller.value + offset) % 1, outer, colors.primary),
            ?child,
          ],
        ),
        child: widget.child,
      ),
    );
  }

  Widget _ring(double t, double outer, Color color) {
    final diameter = widget.size + (outer - widget.size) * t;
    return Opacity(
      opacity: (1 - t) * 0.35,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      ),
    );
  }
}
