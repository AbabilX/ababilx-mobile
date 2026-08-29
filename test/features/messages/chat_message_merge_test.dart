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
}
