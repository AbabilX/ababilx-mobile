import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';

/// What an empty tab says, and the one thing it offers to do about it.
class ConversationListEmpty extends ConsumerWidget {
  const ConversationListEmpty({
    super.key,
    required this.filter,
    required this.onStart,
    required this.onShowAll,
    required this.onFindDevices,
  });

  final ChatListFilter filter;
  final VoidCallback onStart;

  /// Unread with nothing left: leave the tab, don't open compose.
  final VoidCallback onShowAll;

  /// Local Share with no thread: the page that finds devices around you.
  final VoidCallback onFindDevices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    String t(String key) => AppTranslations.translate(context, ref, key);
    final (icon, title, body, action, onAction) = switch (filter) {
      ChatListFilter.unread => (
        HugeIcons.strokeRoundedMailOpen01,
        t('chat_unread_empty_title'),
        t('chat_unread_empty_body'),
        t('chat_show_all_messages'),
        onShowAll,
      ),
      ChatListFilter.groups => (
        HugeIcons.strokeRoundedUserGroup,
        t('home_groups'),
        t('home_no_groups'),
        t('chat_new_message'),
        onStart,
      ),
      ChatListFilter.webhooks => (
        HugeIcons.strokeRoundedWebhook,
        t('chat_filter_webhooks'),
        t('home_no_flock'),
        null,
        null,
      ),
      ChatListFilter.localShare => (
        HugeIcons.strokeRoundedWifi01,
        t('chat_filter_local_share'),
        t('chat_local_share_empty'),
        t('chat_local_share_find'),
        onFindDevices,
      ),
      _ => (
        HugeIcons.strokeRoundedBubbleChat,
        t('chat_empty_title'),
        t('chat_empty_body'),
        t('chat_new_message'),
        onStart,
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(icon, size: 46, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ],
        ),
      ),
    );
  }
}
