import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_read_marks.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _row(String id, {int unread = 3, String? last}) =>
    ChatConversation(
      id: id,
      teamId: '',
      type: 'dm',
      createdAt: '2026-09-01T00:00:00Z',
      unreadCount: unread,
      lastMessageAt: last,
    );

void main() {
  test('a stale sidebar count is zeroed and flagged for re-send', () {
    final marks = ChatReadMarks()..record('a', ['2026-09-22T10:00:00Z']);
    final stale = <String>{};
    final rows = marks.apply(
      [
        _row('a', last: '2026-09-22T10:00:00Z'),
        _row('b', last: '2026-09-22T10:00:00Z'),
      ],
      activeId: null,
      stale: stale,
    );
    expect(rows[0].unreadCount, 0);
    expect(rows[1].unreadCount, 3);
    expect(stale, {'a'});
  });

  test('a message newer than the mark keeps its unread count', () {
    final marks = ChatReadMarks()..record('a', ['2026-09-22T10:00:00Z']);
    final stale = <String>{};
    final rows = marks.apply(
      [_row('a', last: '2026-09-22T10:05:00Z')],
      activeId: null,
      stale: stale,
    );
    expect(rows.single.unreadCount, 3);
    expect(stale, isEmpty);
  });

  test('the conversation on screen is always read', () {
    final stale = <String>{};
    final rows = ChatReadMarks().apply(
      [_row('a', last: '2026-09-22T10:05:00Z')],
      activeId: 'a',
      stale: stale,
    );
    expect(rows.single.unreadCount, 0);
    expect(stale, {'a'});
  });

  test('record keeps the newest time it has seen', () {
    final marks = ChatReadMarks()
      ..record('a', ['2026-09-22T10:05:00Z', null, 'junk'])
      ..record('a', ['2026-09-22T09:00:00Z']);
    final rows = marks.apply(
      [_row('a', last: '2026-09-22T10:05:00Z')],
      activeId: null,
      stale: <String>{},
    );
    expect(rows.single.unreadCount, 0);
  });
}
