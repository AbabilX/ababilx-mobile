import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/models/crm_dashboard.dart';
import '../shared/crm_hex_color.dart';

/// Deal pipeline by stage — horizontal bar chart (industry CRM staple).
class HubDashboardPipelineChart extends StatelessWidget {
  const HubDashboardPipelineChart({super.key, required this.stages});

  final List<CrmStageCount> stages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (stages.isEmpty) {
      return _ChartShell(
        child: Center(
          child: Text(
            'No pipeline stages yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final maxY = stages
        .map((s) => s.count.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b)
        .clamp(1, double.infinity);

    return _ChartShell(
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.15,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colors.inverseSurface,
              getTooltipItem: (group, _, rod, _) {
                final s = stages[group.x.toInt()];
                return BarTooltipItem(
                  '${s.name}\n${s.count}',
                  theme.textTheme.labelSmall!.copyWith(
                    color: colors.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= stages.length) {
                    return const SizedBox.shrink();
                  }
                  final name = stages[i].name;
                  final label = name.length > 8
                      ? '${name.substring(0, 7)}…'
                      : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY <= 2 ? 1 : (maxY / 3).ceilToDouble(),
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.outlineVariant.withValues(alpha: 0.45),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < stages.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: stages[i].count.toDouble(),
                    width: stages.length > 6 ? 12 : 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    color: parseCrmHex(stages[i].color) ?? colors.primary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartShell extends StatelessWidget {
  const _ChartShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deal pipeline',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
