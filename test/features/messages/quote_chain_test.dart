import 'package:ababilx/features/messages/chat-timeline/quote_chain.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg(
  String id,
  int minute, {
  String? quotes,
  bool deleted = false,
}) => ChatMessage.fromJson({
  'id': id,
  'conversation_id': 'c',
  'user_id': 'u',
  'body': id,
  'created_at': DateTime.utc(2026, 10, 7, 10, minute).toIso8601String(),
  if (deleted) 'deleted_at': DateTime.utc(2026, 10, 7, 11).toIso8601String(),
  if (quotes != null) 'quote': {'message_id': quotes},
});

void main() {
  final messages = [
    _msg('root', 0),
    _msg('other', 1),
    _msg('a', 2, quotes: 'root'),
    _msg('b', 3, quotes: 'a'),
    _msg('gone', 4, quotes: 'root', deleted: true),
    _msg('lost', 5, quotes: 'not-on-this-phone'),
  ];

  test('only a message with a live reply counts as quoted', () {
    expect(quotedMessageIds(messages), {'root', 'a', 'not-on-this-phone'});
    expect(quotedMessageIds([messages[0], messages[4]]), isEmpty);
  });

  test('the chain is the root and every reply under it, oldest first', () {
    final ids = quoteChain(messages, 'root').map((m) => m.id).toList();
    expect(ids, ['root', 'a', 'b']);
  });

  test('asking from a reply still starts at the root', () {
    final ids = quoteChain(messages, 'b').map((m) => m.id).toList();
    expect(ids, ['root', 'a', 'b']);
  });

  test('a message that is not on this phone has no chain', () {
    expect(quoteChain(messages, 'missing'), isEmpty);
  });
}
