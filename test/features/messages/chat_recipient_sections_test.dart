import 'package:flutter_test/flutter_test.dart';
import 'package:ababilx/features/messages/chat-recipient-picker/chat_recipient_sections.dart';
import 'package:ababilx/features/messages/chat-recipient-picker/chat_recipient_target.dart';
import 'package:ababilx/features/messages/data/models/chat_connection.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';

ChatConversation _dm(String id, String peerId, String peerName) =>
    ChatConversation(
      id: id,
      teamId: '',
      scope: 'personal',
      type: 'dm',
      createdAt: '2026-09-12T00:00:00Z',
      peerUserId: peerId,
      peerUserName: peerName,
    );

ChatConversation _group(String id, String name) => ChatConversation(
  id: id,
  teamId: '',
  scope: 'personal',
  type: 'group',
  name: name,
  createdAt: '2026-09-12T00:00:00Z',
);

ChatUserSummary _person(String id, String name) =>
    ChatUserSummary(userId: id, name: name, canMessage: true);

List<String> _names(List<ChatRecipientTarget> targets) => [
  for (final t in targets) t.name,
];

void main() {
  group('buildChatRecipientSections', () {
    test('idle list is the newest seven chats, then the groups below', () {
      final conversations = [
        for (var i = 0; i < 9; i++) _dm('dm$i', 'u$i', 'Person $i'),
        _group('g1', 'Late group'),
      ];

      final sections = buildChatRecipientSections(
        conversations: conversations,
        people: const [],
        currentUserId: 'me',
        query: '',
      );

      expect(sections.recent.length, 7);
      expect(_names(sections.groups), ['Late group']);
    });

    test('a search reaches a DM past the recent cap', () {
      final conversations = [
        for (var i = 0; i < 9; i++) _dm('dm$i', 'u$i', 'Person $i'),
        _dm('dm9', 'u9', 'Jibon'),
      ];

      final idle = buildChatRecipientSections(
        conversations: conversations,
        people: const [],
        currentUserId: 'me',
        query: '',
      );
      expect(_names(idle.recent), isNot(contains('Jibon')));
      expect(_names(idle.groups), isNot(contains('Jibon')));

      final found = buildChatRecipientSections(
        conversations: conversations,
        people: const [],
        currentUserId: 'me',
        query: 'jibon',
      );
      expect(_names(found.recent), ['Jibon']);
      expect(found.recent.single.kind, ChatRecipientKind.conversation);
      expect(found.groups, isEmpty);
    });

    test('a search finds a group past the cap too', () {
      final conversations = [
        for (var i = 0; i < 8; i++) _dm('dm$i', 'u$i', 'Person $i'),
        _group('g1', 'Dev team'),
      ];

      final sections = buildChatRecipientSections(
        conversations: conversations,
        people: const [],
        currentUserId: 'me',
        query: 'dev',
      );

      expect(_names(sections.recent), ['Dev team']);
      expect(sections.groups, isEmpty);
    });

    test('a decorated name is found by its plain letters', () {
      final sections = buildChatRecipientSections(
        conversations: [_dm('dm1', 'u1', '⋆·˚ 𝕄𝕦𝕣𝕒𝕕 ˚·⋆')],
        people: const [],
        currentUserId: 'me',
        query: 'murad',
      );

      expect(sections.recent.length, 1);
    });

    test('people are matched by name and by username', () {
      final people = [
        _person('u1', 'Murad Hossain'),
        const ChatUserSummary(
          userId: 'u2',
          name: 'Someone Else',
          username: 'jibon',
          canMessage: true,
        ),
      ];

      final byName = buildChatRecipientSections(
        conversations: const [],
        people: people,
        currentUserId: 'me',
        query: 'murad',
      );
      expect(_names(byName.contacts), ['Murad Hossain']);

      final byHandle = buildChatRecipientSections(
        conversations: const [],
        people: people,
        currentUserId: 'me',
        query: 'jibon',
      );
      expect(_names(byHandle.contacts), ['Someone Else']);
    });

    test('a person already on screen as a chat is not offered twice', () {
      final sections = buildChatRecipientSections(
        conversations: [_dm('dm1', 'u1', 'Murad')],
        people: [_person('u1', 'Murad'), _person('u2', 'Jibon')],
        currentUserId: 'me',
        query: '',
      );

      expect(_names(sections.recent), ['Murad']);
      expect(_names(sections.contacts), ['Jibon']);
    });

    test('a person whose chat is not shown stays reachable as a contact', () {
      final conversations = [
        for (var i = 0; i < 9; i++) _dm('dm$i', 'u$i', 'Person $i'),
      ];

      final sections = buildChatRecipientSections(
        conversations: conversations,
        people: [_person('u8', 'Person 8')],
        currentUserId: 'me',
        query: '',
      );

      expect(_names(sections.contacts), ['Person 8']);
    });
  });

  group('filter capsules', () {
    final conversations = [
      for (var i = 0; i < 9; i++) _dm('dm$i', 'u$i', 'Person $i'),
      _group('g1', 'Alpha team'),
      _group('g2', 'Beta team'),
    ];
    final people = [_person('u0', 'Person 0'), _person('x1', 'Stranger')];

    ChatRecipientSections narrowed(
      ChatRecipientFilter filter, [
      String q = '',
    ]) => buildChatRecipientSections(
      conversations: conversations,
      people: people,
      currentUserId: 'me',
      query: q,
      filter: filter,
    );

    test('Chats lists every DM, past the recent cap, and nothing else', () {
      final sections = narrowed(ChatRecipientFilter.chats);
      expect(sections.recent.length, 9);
      expect(sections.groups, isEmpty);
      expect(sections.contacts, isEmpty);
    });

    test('Groups lists every group and nothing else', () {
      final sections = narrowed(ChatRecipientFilter.groups);
      expect(_names(sections.groups), ['Alpha team', 'Beta team']);
      expect(sections.recent, isEmpty);
      expect(sections.contacts, isEmpty);
    });

    test('Contacts lists people only', () {
      final sections = narrowed(ChatRecipientFilter.contacts);
      expect(_names(sections.contacts), ['Person 0', 'Stranger']);
      expect(sections.recent, isEmpty);
      expect(sections.groups, isEmpty);
    });

    test('a search stays inside the chosen kind', () {
      expect(_names(narrowed(ChatRecipientFilter.groups, 'beta').groups), [
        'Beta team',
      ]);
      expect(narrowed(ChatRecipientFilter.groups, 'person').groups, isEmpty);
    });
  });
}
