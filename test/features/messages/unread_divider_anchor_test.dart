import 'package:ababilx/features/messages/chat-timeline/chat_timeline_unread.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(String id) => ChatMessage(
  id: id,
  conversationId: 'conversation-1',
  userId: 'alice',
  body: id,
  createdAt: '2026-09-03T06:10:00Z',
);

List<ChatMessage> _feed(int count) =>
    List.generate(count, (i) => _message('m${i + 1}'));

void main() {
  group('unreadDividerAnchorId', () {
    test('pins the bar to the oldest unread message', () {
      expect(
        unreadDividerAnchorId(unreadCount: 2, messages: _feed(5)),
        'm4',
      );
    });

    test('a read conversation draws no bar', () {
      expect(unreadDividerAnchorId(unreadCount: 0, messages: _feed(5)), isNull);
    });

    test('a count covering the whole feed draws no bar', () {
      // The bar would sit at the very top with nothing above it to separate.
      expect(unreadDividerAnchorId(unreadCount: 5, messages: _feed(5)), isNull);
      expect(unreadDividerAnchorId(unreadCount: 9, messages: _feed(5)), isNull);
    });

    test('an empty feed draws no bar', () {
      expect(unreadDividerAnchorId(unreadCount: 3, messages: const []), isNull);
    });

    test('the id survives later messages, so the bar cannot slide', () {
      final opened = _feed(5);
      final anchor = unreadDividerAnchorId(unreadCount: 2, messages: opened);
      // Two replies land after the chat opened. Counting back from the end
      // again would move the bar to m6; the pinned id does not.
      final later = [...opened, _message('m6'), _message('m7')];
      expect(
        unreadDividerAnchorId(unreadCount: 2, messages: later),
        isNot(anchor),
      );
      expect(later.map((m) => m.id).contains(anchor), isTrue);
    });
  });
}
