import 'package:ababilx/features/messages/data/chat_message_merge.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(String id, String createdAt, {String body = ''}) =>
    ChatMessage(
      id: id,
      conversationId: 'conversation-1',
      userId: 'user-1',
      body: body,
      createdAt: createdAt,
    );

void main() {
  test('the three copies of one send are one message in any order', () {
    const at = '2026-08-29T06:10:00Z';
    // The local bubble, the socket echo and a history page's copy.
    final bubble = ChatMessage(
      id: 'ref-1',
      conversationId: 'conversation-1',
      userId: 'user-1',
      body: 'hi',
      createdAt: at,
      clientRef: 'ref-1',
      sendStatus: MessageSendStatus.sending,
    );
    final echo = _message(
      'server-1',
      at,
      body: 'hi',
    ).copyWith(clientRef: 'ref-1');
    final paged = _message('server-1', at, body: 'hi');
    final orders = [
      [bubble, echo, paged],
      [bubble, paged, echo],
      [echo, bubble, paged],
      [echo, paged, bubble],
      [paged, echo, bubble],
    ];
    for (final order in orders) {
      final merged = canonicalChatMessages(order);
      expect(merged, hasLength(1), reason: order.map((m) => m.id).join(','));
      expect(merged.single.id, 'server-1');
      expect(merged.single.isPending, isFalse);
    }
  });

  test('a long timeline merges in order without comparing every pair', () {
    final base = DateTime.utc(2026, 8, 1);
    final feed = [
      for (var i = 0; i < 20000; i++)
        _message(
          'm${i.toString().padLeft(6, '0')}',
          base.add(Duration(seconds: i)).toIso8601String(),
        ),
    ];
    final page = [
      for (var i = 19990; i < 20010; i++)
        _message(
          'm${i.toString().padLeft(6, '0')}',
          base.add(Duration(seconds: i)).toIso8601String(),
          body: 'new',
        ),
    ];
    final clock = Stopwatch()..start();
    final merged = canonicalChatMessages([...feed.reversed, ...page]);
    clock.stop();

    expect(merged, hasLength(20010));
    expect(merged.first.id, 'm000000');
    expect(merged.last.id, 'm020009');
    expect(merged[19995].body, 'new');
    // Pairwise, this is 400 million comparisons and takes many seconds.
    expect(clock.elapsedMilliseconds, lessThan(2000));
  });
}
