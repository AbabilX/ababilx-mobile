import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_list_filters.dart';

class ConversationListEmpty extends ConsumerWidget {
  const ConversationListEmpty({
    super.key,
    required this.filter,
    required this.onStart,
    required this.onShowAll,
  });

  final ChatListFilter filter;
  final VoidCallback onStart;

  /// Unread filter with nothing left: leave the filter, don't open compose.
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final unread = filter == ChatListFilter.unread;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unread
                  ? Icons.mark_email_read_outlined
                  : Icons.chat_bubble_outline_rounded,
              size: 46,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.translate(
                context,
                ref,
                unread ? 'chat_unread_empty_title' : 'chat_empty_title',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              AppTranslations.translate(
                context,
                ref,
                unread ? 'chat_unread_empty_body' : 'chat_empty_body',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: unread ? onShowAll : onStart,
              icon: Icon(unread ? Icons.forum_outlined : Icons.edit_outlined),
              label: Text(
                AppTranslations.translate(
                  context,
                  ref,
                  unread ? 'chat_show_all_messages' : 'chat_new_message',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
