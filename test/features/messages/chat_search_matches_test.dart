import 'package:ababilx/features/messages/chat-list/chat_search_matches.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/nickname/contact_nickname.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _dm({
  required String id,
  required String name,
  String? lastMessageAt,
}) => ChatConversation(
  id: id,
  teamId: '',
  scope: 'personal',
  type: 'dm',
  createdAt: '2026-09-01T00:00:00Z',
  lastMessageAt: lastMessageAt,
  peerUserId: id,
  peerUserName: name,
);

ChatConversation _group({required String id, required String name}) =>
    ChatConversation(
      id: id,
      teamId: '',
      scope: 'personal',
      type: 'group',
      createdAt: '2026-09-01T00:00:00Z',
      name: name,
    );

void main() {
  const nicknames = ContactNicknames();

  test('name-matched chats keep input order and ignore message bodies', () {
    final conversations = [
      _dm(id: '1', name: 'Junayed', lastMessageAt: '2026-09-07T00:00:00Z'),
      _dm(id: '2', name: 'Alice', lastMessageAt: '2026-09-08T00:00:00Z'),
      _group(id: '3', name: 'Jungle trek'),
    ];

    final hits = matchingSearchConversations(
      conversations,
      'Jun',
      nicknames: nicknames,
    );

    expect(hits.map((c) => c.id).toList(), ['1', '3']);
  });

  test(
    'a nickname finds the chat even when the account name does not match',
    () {
      const named = ContactNicknames({'p1': 'Junayed'});
      final conversations = [_dm(id: 'p1', name: 'Someone Else')];

      expect(
        matchingSearchConversations(
          conversations,
          'Jun',
          nicknames: named,
        ).single.id,
        'p1',
      );
    },
  );

  test('the original name still matches after a nickname is set', () {
    const named = ContactNicknames({'p1': 'Boss'});
    final conversations = [_dm(id: 'p1', name: 'Junayed')];

    expect(
      matchingSearchConversations(conversations, 'Junayed', nicknames: named),
      isNotEmpty,
    );
  });

  test('queries shorter than two characters match nothing', () {
    expect(
      matchingSearchConversations(
        [_dm(id: '1', name: 'Junayed')],
        'J',
        nicknames: nicknames,
      ),
      isEmpty,
    );
  });
}
