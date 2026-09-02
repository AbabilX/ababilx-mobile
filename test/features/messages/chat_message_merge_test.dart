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
  test('canonical merge keeps one latest copy per id in stable time order', () {
    final merged = canonicalChatMessages([
      _message('m3', '2026-08-29T06:12:00Z'),
      _message('m1', '2026-08-29T06:10:00Z', body: 'old'),
      _message('m2', '2026-08-29T06:11:00Z'),
      _message('m1', '2026-08-29T06:10:00Z', body: 'updated'),
    ]);

    expect(merged.map((message) => message.id), ['m1', 'm2', 'm3']);
    expect(merged.first.body, 'updated');
  });

  test('id breaks equal-time ties deterministically', () {
    final merged = canonicalChatMessages([
      _message('m2', '2026-08-29T06:10:00Z'),
      _message('m1', '2026-08-29T06:10:00Z'),
    ]);

    expect(merged.map((message) => message.id), ['m1', 'm2']);
  });

  test('canonical merge collapses a bubble and its server copy', () {
    final pending = ChatMessage(
      id: 'client-1',
      conversationId: 'conversation-1',
      userId: 'user-1',
      body: 'hello',
      createdAt: '2026-08-29T06:10:00Z',
      sendStatus: MessageSendStatus.sending,
      clientRef: 'client-1',
    );
    final confirmed = ChatMessage(
      id: 'server-1',
      conversationId: 'conversation-1',
      userId: 'user-1',
      body: 'hello',
      createdAt: '2026-08-29T06:10:01Z',
      clientRef: 'client-1',
    );

    final merged = canonicalChatMessages([pending, confirmed]);
    expect(merged, hasLength(1));
    expect(merged.single.id, 'server-1');
    expect(merged.single.sendStatus, MessageSendStatus.sent);
  });

  test(
    'canonical merge keeps one sent row when two copies share a clientRef',
    () {
      final first = ChatMessage(
        id: 'server-1',
        conversationId: 'conversation-1',
        userId: 'user-1',
        body: 'hello',
        createdAt: '2026-08-29T06:10:01Z',
        clientRef: 'client-1',
      );
      final second = ChatMessage(
        id: 'server-1',
        conversationId: 'conversation-1',
        userId: 'user-1',
        body: 'hello',
        createdAt: '2026-08-29T06:10:01Z',
        clientRef: 'client-1',
      );

      expect(canonicalChatMessages([first, second]), hasLength(1));
    },
  );

  test('absent send_status decodes as sent', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'conversation_id': 'c1',
      'user_id': 'u1',
      'body': 'hi',
      'created_at': '2026-08-29T06:10:00Z',
    });
    expect(message.sendStatus, MessageSendStatus.sent);
    expect(message.toJson().containsKey('send_status'), isFalse);
  });

  test(
    'live copy with clientRef and history copy without it stay one message',
    () {
      final live = ChatMessage(
        id: 'server-1',
        conversationId: 'conversation-1',
        userId: 'peer',
        body: 'hello',
        createdAt: '2026-08-29T06:10:01Z',
        clientRef: 'client-1',
      );
      final history = ChatMessage(
        id: 'server-1',
        conversationId: 'conversation-1',
        userId: 'peer',
        body: 'hello',
        createdAt: '2026-08-29T06:10:01Z',
      );

      final merged = canonicalChatMessages([live, history]);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'server-1');
      expect(merged.single.clientRef, 'client-1');
    },
  );

  test(
    'pending bubble and history page without clientRef stay one message',
    () {
      final pending = ChatMessage(
        id: 'client-1',
        conversationId: 'conversation-1',
        userId: 'user-1',
        body: 'ok',
        createdAt: '2026-08-29T06:10:00Z',
        sendStatus: MessageSendStatus.sending,
        clientRef: 'client-1',
      );
      final live = ChatMessage(
        id: 'server-1',
        conversationId: 'conversation-1',
        userId: 'user-1',
        body: 'ok',
        createdAt: '2026-08-29T06:10:01Z',
        clientRef: 'client-1',
      );
      final history = ChatMessage(
        id: 'server-1',
        conversationId: 'conversation-1',
        userId: 'user-1',
        body: 'ok',
        createdAt: '2026-08-29T06:10:01Z',
      );

      final merged = canonicalChatMessages([pending, live, history]);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'server-1');
      expect(merged.single.sendStatus, MessageSendStatus.sent);
      expect(merged.single.clientRef, 'client-1');
    },
  );
}
