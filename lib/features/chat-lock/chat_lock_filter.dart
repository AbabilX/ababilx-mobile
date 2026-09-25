import '../messages/data/models/chat_models.dart';
import 'data/chat_lock_index.dart';

/// [list] without the locked chats. Every surface that lists conversations
/// outside the locked-chats screen goes through this: the chat list, its
/// search, the unread total, the pickers. A locked chat that surfaced in any
/// one of them would say it exists.
List<ChatConversation> withoutLockedChats(
  List<ChatConversation> list,
  Map<String, ChatLockMethod> locks,
) =>
    locks.isEmpty ? list : list.where((c) => !locks.containsKey(c.id)).toList();
