import 'package:flutter/material.dart';

import '../data/models/crm_models.dart';
import '../shared/crm_hex_color.dart';

enum StageStepState { done, current, upcoming }

/// Web stage-step-item: green ✓ done, stage-color/current (red+X if lost), dot upcoming.
class StageStepItem extends StatelessWidget {
  const StageStepItem({
    super.key,
    required this.stage,
    required this.state,
    this.date,
    this.clickable = false,
    this.disabled = false,
    this.onTap,
  });

  final CrmStage stage;
  final StageStepState state;
  final String? date;
  final bool clickable;
  final bool disabled;
  final VoidCallback? onTap;

  static const _green = Color(0xFF22C55E);
  static const _lost = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isCurrent = state == StageStepState.current;
    final isDone = state == StageStepState.done;
    final isUpcoming = state == StageStepState.upcoming;

    late final Color fill;
    late final Color ring;
    late final Color fg;

    if (isDone) {
      fill = _green;
      ring = _green;
      fg = Colors.white;
    } else if (isCurrent) {
      final c = stage.isLost
          ? _lost
          : (parseCrmHex(stage.color) ?? colors.primary);
      fill = c;
      ring = c;
      fg = Colors.white;
    } else {
      fill = Colors.transparent;
      ring = colors.outlineVariant;
      fg = colors.onSurfaceVariant;
    }

    final Widget icon;
    if (isUpcoming) {
      icon = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: colors.outlineVariant,
          shape: BoxShape.circle,
        ),
      );
    } else if (stage.isLost && isCurrent) {
      icon = Icon(Icons.close_rounded, size: 18, color: fg);
    } else {
      icon = Icon(Icons.check_rounded, size: 18, color: fg);
    }

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 2),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            stage.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isUpcoming ? colors.onSurfaceVariant : colors.onSurface,
            ),
          ),
        ),
        if (date != null && date!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            date!,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (!clickable || disabled) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: child,
      ),
    );
  }
}
