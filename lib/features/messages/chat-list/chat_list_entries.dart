import '../../local_share/data/share_thread_queries.dart';
import '../chat_list_filters.dart';
import '../data/models/chat_models.dart';

/// One row of the chat list: a conversation, or a Local Share device thread
/// the user moved here.
sealed class ChatListEntry {
  const ChatListEntry();

  String get key;
}

class ConversationEntry extends ChatListEntry {
  const ConversationEntry(this.conversation);

  final ChatConversation conversation;

  @override
  String get key => conversation.id;
}

class ShareThreadEntry extends ChatListEntry {
  const ShareThreadEntry(this.thread);

  final ShareThread thread;

  @override
  String get key => 'local-share:${thread.device.deviceId}';
}

/// [conversations] already in list order (pinned block first, newest first in
/// each). Device threads go under the pinned block and take their place by
/// time among the rest. A thread has no server row, so the only filters it
/// can answer are All and Unread.
List<ChatListEntry> mergeChatListEntries({
  required List<ChatConversation> conversations,
  required List<ShareThread> threads,
  ChatListFilter filter = ChatListFilter.all,
}) {
  final shown = switch (filter) {
    ChatListFilter.all => threads,
    ChatListFilter.unread => [
      for (final t in threads)
        if (t.unread > 0) t,
    ],
    _ => const <ShareThread>[],
  };
  final entries = <ChatListEntry>[
    for (final c in conversations) ConversationEntry(c),
  ];
  if (shown.isEmpty) return entries;
  final sorted = [...shown]
    ..sort((a, b) => b.lastOrderMs.compareTo(a.lastOrderMs));
  var at = entries.indexWhere(
    (e) => e is ConversationEntry && !e.conversation.pinned,
  );
  if (at < 0) at = entries.length;
  for (final thread in sorted) {
    while (at < entries.length && _atMs(entries[at]) >= thread.lastOrderMs) {
      at++;
    }
    entries.insert(at, ShareThreadEntry(thread));
    at++;
  }
  return entries;
}

int _atMs(ChatListEntry entry) => switch (entry) {
  ConversationEntry(:final conversation) =>
    DateTime.tryParse(
          conversation.lastMessageAt ?? '',
        )?.millisecondsSinceEpoch ??
        0,
  ShareThreadEntry(:final thread) => thread.lastOrderMs,
};
