import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import 'hub_dashboard.dart';
import 'hub_header.dart';
import 'hub_items.dart';
import 'hub_section.dart';

/// WeCom-style CRM workspace hub (dashboard strip + sections).
class CrmHub extends ConsumerWidget {
  const CrmHub({super.key});

  void _onTileTap(BuildContext context, WidgetRef ref, CrmHubItem item) {
    if (item.id == 'contacts') {
      context.go('/crm/contacts');
      return;
    }
    if (item.id == 'leads') {
      context.go('/crm/leads');
      return;
    }
    if (item.id == 'followups') {
      context.go('/crm/followups');
      return;
    }
    final msg = AppTranslations.translate(context, ref, 'crm_coming_soon');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = AppTranslations.translate(context, ref, 'crm');
    final screenH = MediaQuery.sizeOf(context).height;
    // ~45% of screen for industry charts; clamp so tiles still fit.
    final dashH = (screenH * 0.42).clamp(220.0, 340.0);

    return Scaffold(
      appBar: CrmHubHeader(title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          ShellPillMetrics.contentBottomInset,
        ),
        children: [
          CrmHubDashboard(height: dashH),
          const SizedBox(height: 10),
          for (final section in kCrmHubSections) ...[
            CrmHubSection(
              title: AppTranslations.translate(context, ref, section.titleKey),
              items: section.items,
              labelOf: (item) =>
                  AppTranslations.translate(context, ref, item.labelKey),
              onTileTap: (item) => _onTileTap(context, ref, item),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
