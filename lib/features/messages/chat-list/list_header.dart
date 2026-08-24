import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/chat_scope_provider.dart';
import 'chat_search.dart';
import 'header_profile_pill.dart';
import 'you-sheet/index.dart';
import 'you-sheet/you_sheet_action.dart';

enum _ChatHeaderAction { unread, all, personal, workspaces, people }

class ChatListHeader extends ConsumerWidget {
  const ChatListHeader({
    super.key,
    required this.unreadOnly,
    required this.onToggleUnread,
  });

  final bool unreadOnly;
  final VoidCallback onToggleUnread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).valueOrNull;
    final name = user?.name.isNotEmpty == true ? user!.name : 'You';
    final independent = user?.independentChat ?? false;
    final scope = ref.watch(chatScopeProvider);

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
            PopupMenuButton<_ChatHeaderAction>(
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              onSelected: (action) => _handleAction(context, ref, action),
              itemBuilder: (_) => [
                _item(
                  _ChatHeaderAction.unread,
                  AppTranslations.translate(context, ref, 'chat_unread'),
                  unreadOnly,
                ),
                if (independent) const PopupMenuDivider(),
                if (independent)
                  _item(
                    _ChatHeaderAction.all,
                    AppTranslations.translate(context, ref, 'chat_all'),
                    scope == ChatScopeFilter.all,
                  ),
                if (independent)
                  _item(
                    _ChatHeaderAction.personal,
                    AppTranslations.translate(context, ref, 'chat_personal'),
                    scope == ChatScopeFilter.personal,
                  ),
                if (independent)
                  _item(
                    _ChatHeaderAction.workspaces,
                    AppTranslations.translate(context, ref, 'chat_workspaces'),
                    scope == ChatScopeFilter.workspaces,
                  ),
                if (independent) const PopupMenuDivider(),
                if (independent)
                  PopupMenuItem(
                    value: _ChatHeaderAction.people,
                    child: Text(
                      AppTranslations.translate(context, ref, 'chat_people'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_ChatHeaderAction> _item(
    _ChatHeaderAction value,
    String label,
    bool selected,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        SizedBox(width: 28, child: selected ? const Icon(Icons.check) : null),
        Text(label),
      ],
    ),
  );

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    _ChatHeaderAction action,
  ) {
    switch (action) {
      case _ChatHeaderAction.unread:
        onToggleUnread();
        return;
      case _ChatHeaderAction.all:
        ref.read(chatScopeProvider.notifier).state = ChatScopeFilter.all;
        return;
      case _ChatHeaderAction.personal:
        ref.read(chatScopeProvider.notifier).state = ChatScopeFilter.personal;
        return;
      case _ChatHeaderAction.workspaces:
        ref.read(chatScopeProvider.notifier).state = ChatScopeFilter.workspaces;
        return;
      case _ChatHeaderAction.people:
        context.push('/messages/people');
        return;
    }
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
