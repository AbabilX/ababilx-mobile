import '../../chat-lock/chat_lock_filter.dart';
import '../../chat-lock/data/chat_lock_index.dart';
import '../chat-details/group_permissions.dart';
import '../chat_list_filters.dart';
import '../data/models/chat_conversation.dart';

/// Chats that can take a share or a forward, in chat-list order. The picker
/// and the system share sheet's Direct Share targets both read this, so a
/// chat offered in one is never refused by the other.
List<ChatConversation> shareableConversations({
  required List<ChatConversation> dms,
  required List<ChatConversation> channels,
  required Map<String, ChatLockMethod> locks,
  String? excludedConversationId,
}) =>
    unifiedConversations(
          dms: withoutLockedChats(dms, locks),
          channels: withoutLockedChats(channels, locks),
        )
        .where(
          (c) =>
              c.canMessage &&
              // A group an admin made this member read-only in (server 0157) takes
              // nothing by forward either.
              GroupPermissions(c).canSend &&
              c.archivedAt == null &&
              c.id != excludedConversationId,
        )
        .toList();
