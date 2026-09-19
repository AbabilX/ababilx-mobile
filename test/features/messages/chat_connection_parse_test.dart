import 'package:ababilx/features/messages/chat-people/connections_filter.dart';
import 'package:ababilx/features/messages/data/models/chat_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson accepts non-string ids and timestamps', () {
    final row = ChatConnection.fromJson({
      'id': 1,
      'status': 'accepted',
      'direction': 'outgoing',
      'created_at': DateTime.utc(2026, 9, 19),
      'user': {'user_id': 2, 'name': 'Ada', 'can_message': true},
    });
    expect(row.id, '1');
    expect(row.user.userId, '2');
    expect(row.user.canMessage, isTrue);
    expect(row.createdAt, isNotEmpty);
  });

  test('filterConnections matches name and @username', () {
    const ada = ChatUserSummary(
      userId: '1',
      name: 'Ada Lovelace',
      username: 'ada',
    );
    const bob = ChatUserSummary(userId: '2', name: 'Bob', username: 'bob42');
    final list = [
      ChatConnection(
        id: 'a',
        user: ada,
        status: 'accepted',
        direction: 'outgoing',
        createdAt: '',
      ),
      ChatConnection(
        id: 'b',
        user: bob,
        status: 'accepted',
        direction: 'incoming',
        createdAt: '',
      ),
    ];
    expect(filterConnections(list, 'lovelace'), [list[0]]);
    expect(filterConnections(list, '@bob'), [list[1]]);
    expect(filterConnections(list, ''), list);
  });
}
