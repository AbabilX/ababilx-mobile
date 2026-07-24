import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/chat-empty-state/index.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../crm-hub/index.dart';

/// CRM tab root — team gate then WeCom-style hub shell.
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
              subtitle:
                  'Join or create a team on the web to use CRM.',
              icon: Icons.groups_outlined,
            ),
          );
        }
        return const CrmHub();
      },
    );
  }
}
