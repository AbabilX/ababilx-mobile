import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../profile/providers/profile_provider.dart';
import 'chat_search.dart';
import 'header_profile_pill.dart';
import 'you-sheet/index.dart';
import 'you-sheet/you_sheet_action.dart';

/// Chat list header: identity pill, title, search, and Local Share.
///
/// Settings lives behind the avatar (You sheet), so this slot is free for a
/// second destination rather than duplicating that path. Local Share needs
/// its own always-visible entry point — it is how a nearby device starts a
/// transfer, and it has no other icon anywhere in the shell. The filters this
/// row used to hold — unread and the personal/workspace scope — live in the
/// pill row under this header now (Slack's arrangement), where the current
/// selection is visible without opening anything.
class ChatListHeader extends ConsumerWidget {
  const ChatListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).valueOrNull;
    final name = user?.name.isNotEmpty == true ? user!.name : 'You';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            HeaderProfilePill(
              name: name,
              avatarUrl: user?.avatarUrl,
              currentUserId: user?.id,
              onProfileTap: () => _openYouSheet(context, ref),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'AbabilX',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: () => openChatSearch(context, ref),
              icon: const Icon(Icons.search_rounded),
              tooltip: MaterialLocalizations.of(context).searchFieldLabel,
            ),
            IconButton(
              onPressed: () => context.push('/local-share'),
              icon: const Icon(Icons.wifi_tethering_rounded),
              tooltip: 'Local Share',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openYouSheet(BuildContext context, WidgetRef ref) async {
    ref.read(shellBottomBarHiddenProvider.notifier).state = true;
    YouSheetAction? action;
    try {
      action = await showYouSheet(context);
    } finally {
      ref.read(shellBottomBarHiddenProvider.notifier).state = false;
    }
    if (!context.mounted) return;
    if (action == YouSheetAction.scanQrLogin) {
      await QrLoginFlow.start(context, ref);
    } else if (action == YouSheetAction.localShare) {
      context.push('/local-share');
    }
  }
}
