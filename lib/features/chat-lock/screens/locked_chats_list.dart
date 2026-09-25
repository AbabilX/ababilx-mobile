import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-list/conversation_avatar.dart';
import '../../messages/chat_icon.dart';
import '../../messages/chat_list_filters.dart';
import '../../messages/chat_unread_badge.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import '../providers/chat_lock_session.dart';

/// The opened locked-chats list. Rows carry no message preview: the list
/// being open says who, a chat being open says what.
///
/// Only chats revealed by the unlock that opened the folder — matching
/// password, or phone-lock chats after the phone lock. Another password's
/// chat is not named here.
class LockedChatsList extends ConsumerWidget {
  const LockedChatsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final ids = ref.watch(
      chatLockSessionProvider.select((s) => s.folderVisible),
    );
    final state = ref.watch(chatProvider);
    final nicknames = ref.watch(contactNicknamesProvider);
    final chats = <ChatConversation>[
      for (final c in [...state.dms, ...state.channels])
        if (ids.contains(c.id)) c,
    ]..sort((a, b) => (b.lastMessageAt ?? '').compareTo(a.lastMessageAt ?? ''));
    final colors = Theme.of(context).colorScheme;

    if (chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t('chatlock_folder_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, i) {
        final c = chats[i];
        final title = nicknames.titleFor(c, state.currentUserId);
        return ListTile(
          leading: ConversationAvatar(conversation: c, title: title),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Row(
            children: [
              ChatIcon(
                HugeIcons.strokeRoundedSquareLock02,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(t('chatlock_row_locked')),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                relativeChatTime(c.lastMessageAt),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              ChatUnreadBadge(count: c.unreadCount),
            ],
          ),
          onTap: () => context.push('/messages/${c.id}'),
        );
      },
    );
  }
}
