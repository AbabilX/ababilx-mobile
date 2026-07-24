import 'package:flutter/material.dart';

import '../data/models/crm_models.dart';

enum StageStepState { done, current, upcoming }

/// One circle in the pipeline stepper.
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isCurrent = state == StageStepState.current;
    final isDone = state == StageStepState.done;

    final ring = isCurrent
        ? colors.primary
        : isDone
            ? colors.tertiary
            : colors.outlineVariant;
    final fill = isCurrent
        ? colors.primary
        : isDone
            ? colors.tertiaryContainer
            : colors.surfaceContainerHighest;
    final fg = isCurrent
        ? colors.onPrimary
        : isDone
            ? colors.onTertiaryContainer
            : colors.onSurfaceVariant;

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: isCurrent ? 2.5 : 1.5),
          ),
          alignment: Alignment.center,
          child: isDone
              ? Icon(Icons.check_rounded, size: 18, color: fg)
              : Text(
                  '${stage.position + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
              color: isCurrent ? colors.onSurface : colors.onSurfaceVariant,
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
