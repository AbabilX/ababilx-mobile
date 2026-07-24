import 'package:flutter/material.dart';

import '../shared/crm_money.dart';

/// Industry-standard money strip: open pipeline + won revenue.
class HubDashboardMoney extends StatelessWidget {
  const HubDashboardMoney({
    super.key,
    required this.pipelineValue,
    required this.wonValue,
    required this.currency,
  });

  final double pipelineValue;
  final double wonValue;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: _MoneyTile(
            title: 'Pipeline',
            value: formatCrmMoney(pipelineValue, currency),
            accent: colors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MoneyTile(
            title: 'Won',
            value: formatCrmMoney(wonValue, currency),
            accent: colors.tertiary,
          ),
        ),
      ],
    );
  }
}

class _MoneyTile extends StatelessWidget {
  const _MoneyTile({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
