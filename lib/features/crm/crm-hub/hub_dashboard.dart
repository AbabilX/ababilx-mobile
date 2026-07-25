import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/crm_contacts_provider.dart';
import '../providers/crm_dashboard_provider.dart';
import 'dashboard_money.dart';
import 'dashboard_pipeline_chart.dart';

/// Top ~half of CRM hub: money + pipeline chart from dashboard API.
class CrmHubDashboard extends ConsumerWidget {
  const CrmHubDashboard({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(crmDashboardProvider);
    final currency =
        ref.watch(crmConfigProvider).valueOrNull?.settings.currency ?? 'BDT';
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: dashAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (e, _) => Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            e.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
          ),
        ),
        data: (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HubDashboardMoney(
              pipelineValue: d.pipelineValue,
              wonValue: d.wonValue,
              currency: currency,
            ),
            const SizedBox(height: 10),
            Expanded(child: HubDashboardPipelineChart(stages: d.stageCounts)),
          ],
        ),
      ),
    );
  }
}
