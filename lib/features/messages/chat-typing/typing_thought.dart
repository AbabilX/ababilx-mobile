import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Animated thought-bubble glyph while a DM peer is typing.
///
/// Soft scale + opacity pulse — the icon itself is the bubble, so the timeline
/// row does not wrap another [MessageBubble] around it.
class TypingThoughtIcon extends StatefulWidget {
  const TypingThoughtIcon({super.key, required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  State<TypingThoughtIcon> createState() => _TypingThoughtIconState();
}

class _TypingThoughtIconState extends State<TypingThoughtIcon>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1200);
  static const _minScale = 0.88;
  static const _minAlpha = 0.55;

  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _cycle)
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        final scale = _minScale + (1 - _minScale) * t;
        final alpha = _minAlpha + (1 - _minAlpha) * t;
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: alpha, child: child),
        );
      },
      child: ChatIcon(
        HugeIcons.strokeRoundedThoughtBubble,
        size: widget.size,
        color: widget.color,
        strokeWidth: 1.5,
      ),
    );
  }
}
