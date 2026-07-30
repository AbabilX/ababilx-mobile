import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/team_gate_provider.dart';
import 'header_profile_pill.dart';
import 'workspace_title.dart';
import 'you-sheet/index.dart';

/// Slack-style list app bar: workspace left, history+profile pill right.
class ChatListHeader extends ConsumerWidget {
  const ChatListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamGateProvider).valueOrNull?.team;
    final user = ref.watch(profileProvider).valueOrNull;
    final workspaceName = team?.name.isNotEmpty == true
        ? team!.name
        : 'Workspace';
    final userName = user?.name.isNotEmpty == true ? user!.name : 'You';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: WorkspaceTitle(
              name: workspaceName,
              avatarUrl: team?.avatarUrl,
            ),
          ),
          HeaderProfilePill(
            name: userName,
            avatarUrl: user?.avatarUrl,
            currentUserId: user?.id,
            onProfileTap: () => _openYouSheet(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _openYouSheet(BuildContext context, WidgetRef ref) async {
    final shellChrome = ref.read(shellBottomBarHiddenProvider.notifier);
    shellChrome.state = true;
    try {
      await showYouSheet(context);
    } finally {
      shellChrome.state = false;
    }
  }
}
