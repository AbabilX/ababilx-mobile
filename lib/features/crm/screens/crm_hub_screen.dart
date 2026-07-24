import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-empty-state/index.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../crm-hub/index.dart';

/// CRM tab root — team + premium/crm_access gate, then WeCom-style hub.
class CrmHubScreen extends ConsumerWidget {
  const CrmHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamGateProvider);

    return teamAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (_, _) => const Scaffold(
        body: ChatEmptyState(
          title: 'Could not load team',
          subtitle: 'Pull to refresh or try again later.',
          icon: Icons.error_outline,
        ),
      ),
      data: (detail) {
        if (detail == null || !detail.hasTeam) {
          return const Scaffold(
            body: ChatEmptyState(
              title: 'No team yet',
              subtitle: 'Join or create a team on the web to use CRM.',
              icon: Icons.groups_outlined,
            ),
          );
        }
        // Mirror web TeamNavGate(navKey: "crm"): premium + crm_access.
        if (!detail.canViewCrm) {
          return Scaffold(
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
        return const CrmHub();
      },
    );
  }
}
