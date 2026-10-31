import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat-lock/chat_lock_filter.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';
import '../../messages/chat_list_filters.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/providers/chat_sidebar_slice.dart';

/// Every conversation Home may show, newest first, pinned first — the chat
/// list's own order. Locked chats are left out here exactly as the chat list
/// leaves them out: they live behind the title's long press and nowhere else.
final homeConversationsProvider = Provider.autoDispose<List<ChatConversation>>((
  ref,
) {
  final chat = ref.watch(chatSidebarProvider);
  final locks = ref.watch(chatLocksProvider);
  return unifiedConversations(
    dms: withoutLockedChats(chat.dms, locks),
    channels: withoutLockedChats(chat.channels, locks),
  );
});

/// Chats with something unread, the Unread card and page.
final homeUnreadProvider = Provider.autoDispose<List<ChatConversation>>(
  (ref) => [
    for (final c in ref.watch(homeConversationsProvider))
      if (matchesChatListFilter(c, ChatListFilter.unread)) c,
  ],
);

/// Groups people talk in — the chat list's Groups pill. Feeds are left out:
/// nobody writes into one, and they would bury the groups.
final homeGroupsProvider = Provider.autoDispose<List<ChatConversation>>(
  (ref) => [
    for (final c in ref.watch(homeConversationsProvider))
      if (matchesChatListFilter(c, ChatListFilter.groups)) c,
  ],
);

/// Flock: webhook feeds, the chat list's Flock pill.
final homeFlockProvider = Provider.autoDispose<List<ChatConversation>>(
  (ref) => [
    for (final c in ref.watch(homeConversationsProvider))
      if (matchesChatListFilter(c, ChatListFilter.webhooks)) c,
  ],
);

/// Pinned chats, Home's fast-access row.
final homePinnedProvider = Provider.autoDispose<List<ChatConversation>>(
  (ref) => [
    for (final c in ref.watch(homeConversationsProvider))
      if (c.pinned) c,
  ],
);

/// Newest chats first, pinned ones left out (they have their own row).
final homeRecentsProvider = Provider.autoDispose<List<ChatConversation>>(
  (ref) => [
    for (final c in ref.watch(homeConversationsProvider))
      if (!c.pinned) c,
  ],
);

/// Messages waiting in [conversations] that are unread, for "12 new".
int unreadMessageCount(List<ChatConversation> conversations) =>
    conversations.fold(0, (sum, c) => sum + c.unreadCount);

/// [id] among the conversations Home may show, or null (locked, left, gone).
ChatConversation? homeConversationById(
  List<ChatConversation> conversations,
  String id,
) {
  for (final c in conversations) {
    if (c.id == id) return c;
  }
  return null;
}
