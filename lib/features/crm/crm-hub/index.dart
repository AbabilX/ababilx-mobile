import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import 'hub_header.dart';
import 'hub_items.dart';
import 'hub_section.dart';

/// WeCom-style CRM workspace hub (sections + icon tiles).
class CrmHub extends ConsumerWidget {
  const CrmHub({super.key});

  void _onTileTap(BuildContext context, WidgetRef ref, CrmHubItem item) {
    if (item.id == 'contacts') {
      context.go('/crm/contacts');
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

    return Scaffold(
      appBar: CrmHubHeader(title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final section in kCrmHubSections) ...[
            CrmHubSection(
              title: AppTranslations.translate(context, ref, section.titleKey),
              items: section.items,
              labelOf: (item) =>
                  AppTranslations.translate(context, ref, item.labelKey),
              onTileTap: (item) => _onTileTap(context, ref, item),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
