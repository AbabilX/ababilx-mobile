import '../data/chat_message_merge.dart';
import '../data/models/chat_message.dart';

/// Messages that arrived over the socket for a feed nobody has opened yet.
///
/// The socket path persists every message, but that write is asynchronous and
/// the open path reads disk — so a DM opened the instant its preview appears
/// read a page that did not hold the message yet, and the bubble only showed
/// up after the network refresh. The copy here is already decrypted, so the
/// open merges it on the first frame instead of waiting on disk or a request.
///
/// Bounded both ways: a feed keeps its newest [perFeed], and the least
/// recently touched feed is dropped past [maxFeeds]. It is a bridge until the
/// feed exists, never an archive — disk remains the archive.
class ReceivedMessageBuffer {
  ReceivedMessageBuffer({this.perFeed = 50, this.maxFeeds = 64});

  final int perFeed;
  final int maxFeeds;

  /// Insertion-ordered, so the first key is the least recently touched.
  final _feeds = <String, List<ChatMessage>>{};

  bool get isEmpty => _feeds.isEmpty;

  /// Buffered copies for [key], oldest first. Empty when none.
  List<ChatMessage> peek(String key) => List.unmodifiable(_feeds[key] ?? []);

  void add(String key, ChatMessage message) {
    final current = _feeds.remove(key) ?? const <ChatMessage>[];
    var next = canonicalChatMessages([...current, message]);
    if (next.length > perFeed) next = next.sublist(next.length - perFeed);
    _feeds[key] = next;
    while (_feeds.length > maxFeeds) {
      _feeds.remove(_feeds.keys.first);
    }
  }

  /// Replaces a buffered copy in place — an edit or a reaction that landed
  /// before the feed was opened. A message not in the buffer is ignored.
  void patch(String messageId, ChatMessage Function(ChatMessage) change) {
    for (final entry in _feeds.entries) {
      final list = entry.value;
      final index = list.indexWhere((m) => m.id == messageId);
      if (index < 0) continue;
      _feeds[entry.key] = [
        ...list.sublist(0, index),
        change(list[index]),
        ...list.sublist(index + 1),
      ];
    }
  }

  void remove(String messageId) {
    for (final key in _feeds.keys.toList()) {
      final next = _feeds[key]!.where((m) => m.id != messageId).toList();
      if (next.isEmpty) {
        _feeds.remove(key);
      } else {
        _feeds[key] = next;
      }
    }
  }

  /// Drops every feed of [conversationId], threads included.
  void forgetConversation(String conversationId) {
    _feeds.removeWhere(
      (key, _) =>
          key == conversationId || key.startsWith('$conversationId:thread:'),
    );
  }

  /// Hands the buffered copies over to a feed that now exists in memory. From
  /// that moment the feed holds them; keeping them here too would let a later
  /// merge resurrect a message the feed has since dropped.
  List<ChatMessage> take(String key) => _feeds.remove(key) ?? const [];

  void clear() => _feeds.clear();
}
