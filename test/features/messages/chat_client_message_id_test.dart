import 'package:ababilx/features/messages/data/chat_client_message_id.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client message ids are unique UUIDs', () {
    final first = newChatClientMessageId();
    final second = newChatClientMessageId();
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(first, matches(uuid));
    expect(second, matches(uuid));
    expect(second, isNot(first));
  });

  test('server messages preserve their client message id', () {
    final message = ChatMessage.fromJson({
      'id': 'server-message-1',
      'client_message_id': '5af4c787-1337-4809-817e-d2221fd95144',
      'conversation_id': 'conversation-1',
      'user_id': 'user-1',
      'body': 'hello',
      'created_at': '2026-09-01T00:00:00Z',
    });

    expect(message.clientRef, '5af4c787-1337-4809-817e-d2221fd95144');
    expect(
      message.toJson()['client_message_id'],
      '5af4c787-1337-4809-817e-d2221fd95144',
    );
  });
}
