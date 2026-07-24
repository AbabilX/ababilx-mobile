import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-empty-state/index.dart';
import '../chat-sidebar/index.dart';
import '../providers/team_gate_provider.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamGateProvider);

    return Scaffold(
      body: teamAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        error: (_, __) => const ChatEmptyState(
          title: 'Could not load team',
          subtitle: 'Pull to refresh or try again later.',
          icon: Icons.error_outline,
        ),
        data: (detail) {
          if (detail == null || !detail.hasTeam) {
            return const ChatEmptyState(
              title: 'No team yet',
              subtitle:
                  'Join or create a team on the web to use workspace messages.',
              icon: Icons.groups_outlined,
            );
          }
          return const ChatSidebar();
        },
      ),
    );
  }
}
