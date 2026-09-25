import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_list_filters.dart';
import '../providers/chat_provider.dart';
import 'chat_search_section_header.dart';
import 'conversation_row.dart';
import 'recent_contacts_strip.dart';
import '../../chat-lock/chat_lock_filter.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';

/// What the search screen shows before anything is typed: the people and
/// groups most likely to be the target, one tap from opening. A bare
/// "Type to search" label gave the empty screen nothing to act on.
///
/// Local only — the sidebar is already on this phone, so nothing is fetched.
class ChatSearchSuggestions extends ConsumerWidget {
  const ChatSearchSuggestions({super.key, required this.onOpenConversation});

  final ValueChanged<String> onOpenConversation;

  static const _groupLimit = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    String tr(String key) => AppTranslations.translate(context, ref, key);

    final locks = ref.watch(chatLocksProvider);
    final people = recentDmsForStrip(withoutLockedChats(chat.dms, locks));
    final groups = unifiedConversations(
      dms: const [],
      channels: withoutLockedChats(chat.channels, locks),
    ).take(_groupLimit).toList();

    if (people.isEmpty && groups.isEmpty) {
      return Center(child: Text(tr('chat_search_min_chars')));
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (people.isNotEmpty) ...[
          ChatSearchSectionHeader(label: tr('chat_search_recent')),
          RecentContactsStrip(
            conversations: people,
            currentUserId: chat.currentUserId,
            onTap: (conversation) => onOpenConversation(conversation.id),
          ),
        ],
        if (groups.isNotEmpty) ...[
          ChatSearchSectionHeader(label: tr('chat_groups')),
          for (final conversation in groups)
            ConversationRow(
              conversation: conversation,
              currentUserId: chat.currentUserId,
              onTap: () => onOpenConversation(conversation.id),
            ),
        ],
      ],
    );
  }
}
