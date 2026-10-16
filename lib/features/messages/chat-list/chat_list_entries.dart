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
  const ShareThreadEntry(this.thread, {this.pinned = false});

  final ShareThread thread;
  final bool pinned;

  @override
  String get key => 'local-share:${thread.device.deviceId}';
}

/// [conversations] already in list order (pinned block first, newest first in
/// each). A device thread the user pinned ([pinnedThreads], device ids) joins
/// the pinned block by time; the others go under it and take their place by
/// time among the rest. A thread has no server row, so the only filters it
/// can answer are All, Unread and Local Share.
List<ChatListEntry> mergeChatListEntries({
  required List<ChatConversation> conversations,
  required List<ShareThread> threads,
  ChatListFilter filter = ChatListFilter.all,
  Set<String> pinnedThreads = const {},
}) {
  final shown = switch (filter) {
    ChatListFilter.all || ChatListFilter.localShare => threads,
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
  // Pinned threads first, into the pinned block (which ends where the first
  // unpinned conversation starts), then the rest below it.
  for (final pinned in [true, false]) {
    var at = pinned ? 0 : entries.indexWhere((e) => !_isPinned(e));
    if (at < 0) at = entries.length;
    for (final thread in sorted) {
      if (pinnedThreads.contains(thread.device.deviceId) != pinned) continue;
      while (at < entries.length &&
          (pinned ? _isPinned(entries[at]) : true) &&
          _atMs(entries[at]) >= thread.lastOrderMs) {
        at++;
      }
      entries.insert(at, ShareThreadEntry(thread, pinned: pinned));
      at++;
    }
  }
  return entries;
}

bool _isPinned(ChatListEntry e) => switch (e) {
  ConversationEntry(:final conversation) => conversation.pinned,
  ShareThreadEntry(:final pinned) => pinned,
};

int _atMs(ChatListEntry entry) => switch (entry) {
  ConversationEntry(:final conversation) =>
    DateTime.tryParse(
          conversation.lastMessageAt ?? '',
        )?.millisecondsSinceEpoch ??
        0,
  ShareThreadEntry(:final thread) => thread.lastOrderMs,
};
