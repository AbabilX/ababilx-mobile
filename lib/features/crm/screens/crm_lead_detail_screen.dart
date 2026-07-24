import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-empty-state/index.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../crm-lead-detail/index.dart';

/// Lead detail route — CRM gate then detail page (outside shell).
class CrmLeadDetailScreen extends ConsumerWidget {
  const CrmLeadDetailScreen({super.key, required this.leadId});

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamGateProvider);

    return teamAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const ChatEmptyState(
          title: 'Could not load team',
          subtitle: 'Pull to refresh or try again later.',
          icon: Icons.error_outline,
        ),
      ),
      data: (detail) {
        if (detail == null || !detail.canViewCrm) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: ChatEmptyState(
              title: AppTranslations.translate(context, ref, 'crm_no_access'),
              subtitle: AppTranslations.translate(
                context,
                ref,
                'crm_no_access_body',
              ),
              icon: Icons.lock_outline,
            ),
          );
        }
        return CrmLeadDetailPage(leadId: leadId);
      },
    );
  }
}
