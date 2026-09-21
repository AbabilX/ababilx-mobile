import '../data/models/chat_models.dart';

/// What this device has read, remembered until the server agrees.
///
/// `markRead` is a POST, and a sidebar fetch that set off before it landed
/// answers with the old count. The list replaces its rows wholesale, so a
/// conversation the reader has just opened came back as unread and stayed that
/// way until the next refetch. The same happened when the POST itself failed
/// offline. Each mark records the newest message time the reader has seen: a
/// row whose last message is no newer than that is read, whatever the count
/// says. A newer message means the unread count is real, and the mark
/// does not hide it.
class ChatReadMarks {
  final Map<String, DateTime> _readUpTo = {};

  /// Records that [conversationId] is read up to the newest of [times]
  /// (ISO strings from the server; unparseable ones are ignored).
  void record(String conversationId, Iterable<String?> times) {
    var newest = _readUpTo[conversationId];
    for (final raw in times) {
      final at = raw == null ? null : DateTime.tryParse(raw);
      if (at != null && (newest == null || at.isAfter(newest))) newest = at;
    }
    if (newest != null) _readUpTo[conversationId] = newest;
  }

  void clear() => _readUpTo.clear();

  /// Zeroes the count of every row that a mark says is read, and of the
  /// conversation on screen. [stale] collects the rows where the server still
  /// counted unread, so the caller can send `markRead` again.
  List<ChatConversation> apply(
    List<ChatConversation> rows, {
    required String? activeId,
    required Set<String> stale,
  }) => [
    for (final row in rows)
      if (row.unreadCount > 0 && _isRead(row, activeId))
        _zeroed(row, stale)
      else
        row,
  ];

  ChatConversation _zeroed(ChatConversation row, Set<String> stale) {
    stale.add(row.id);
    return row.copyWith(unreadCount: 0);
  }

  bool _isRead(ChatConversation row, String? activeId) {
    if (row.id == activeId) return true;
    final upTo = _readUpTo[row.id];
    if (upTo == null) return false;
    final last = DateTime.tryParse(row.lastMessageAt ?? '');
    if (last == null) return false;
    if (last.isAfter(upTo)) {
      // A message arrived after the mark, so the server's count is real.
      _readUpTo.remove(row.id);
      return false;
    }
    return true;
  }
}
