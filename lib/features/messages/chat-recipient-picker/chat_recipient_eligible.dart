import '../../chat-lock/chat_lock_filter.dart';
import '../../chat-lock/data/chat_lock_index.dart';
import '../chat-details/group_permissions.dart';
import '../data/models/chat_conversation.dart';

/// Chats that can take a share or a forward, most recent message first. The
/// picker and the system share sheet's Direct Share targets both read this,
/// so a chat offered in one is never refused by the other.
///
/// Recency alone, not chat-list order: the list puts pinned chats on top,
/// and a share sheet's "Recent" row filled with pins reads as stale — the
/// chat just written in sat below them. The reference app and WhatsApp offer
/// the most recent chats there.
List<ChatConversation> shareableConversations({
  required List<ChatConversation> dms,
  required List<ChatConversation> channels,
  required Map<String, ChatLockMethod> locks,
  String? excludedConversationId,
}) {
  final eligible =
      [
        ...withoutLockedChats(dms, locks),
        ...withoutLockedChats(channels, locks),
      ].where(
        (c) =>
            c.canMessage &&
            // A group an admin made this member read-only in (server 0157)
            // takes nothing by forward either.
            GroupPermissions(c).canSend &&
            c.archivedAt == null &&
            c.id != excludedConversationId,
      );
  // Each time parsed once, not once per comparison.
  final ranked = [
    for (final c in eligible)
      (
        c,
        DateTime.tryParse(c.lastMessageAt ?? '')?.millisecondsSinceEpoch ?? 0,
      ),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final entry in ranked) entry.$1];
}
