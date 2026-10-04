import 'package:flutter/material.dart';

import '../chat_icon.dart';
import 'selection_action_bar.dart';

/// A capsule with an icon and a word — the bottom bar's Reply and Forward.
class SelectionLabelCapsule extends StatelessWidget {
  const SelectionLabelCapsule({
    super.key,
    required this.item,
    required this.iconFirst,
    this.bare = false,
    this.ripple,
  });

  final SelectionAction item;
  final bool iconFirst;

  /// Too narrow for its content: draw the pill alone.
  final bool bare;

  /// 0..1 progress of a ring spreading from the leading edge, or null for
  /// none. Painted inside the capsule, so its shape clips it.
  final double? ripple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    final icon = ChatIcon(item.icon, size: 20, color: color, strokeWidth: 1.5);
    final label = Flexible(
      child: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final progress = ripple;
    return SelectionCapsule(
      onTap: item.onPressed,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (progress != null)
            CustomPaint(
              painter: _RipplePainter(
                progress: progress,
                color: color,
                fromStart: Directionality.of(context) == TextDirection.ltr,
              ),
            ),
          if (!bare)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: iconFirst
                    ? [icon, const SizedBox(width: 8), label]
                    : [label, const SizedBox(width: 8), icon],
              ),
            ),
        ],
      ),
    );
  }
}

/// Two rings running outward from the edge the capsule grew from, the second
/// trailing the first, both thinning as they go — a drop landing in water.
class _RipplePainter extends CustomPainter {
  const _RipplePainter({
    required this.progress,
    required this.color,
    required this.fromStart,
  });

  final double progress;
  final Color color;
  final bool fromStart;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(fromStart ? 0 : size.width, size.height / 2);
    for (final delay in const [0.0, 0.22]) {
      final p = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final eased = Curves.easeOutCubic.transform(p);
      canvas.drawCircle(
        origin,
        size.width * eased,
        Paint()..color = color.withValues(alpha: 0.14 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}
