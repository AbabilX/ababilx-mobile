import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/chat_list_filters.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';

ChatConversation _conv(String id, String type, {int unread = 0}) =>
    ChatConversation(
      id: id,
      teamId: '',
      scope: 'personal',
      type: type,
      createdAt: '2026-09-01T00:00:00Z',
      lastMessageAt: '2026-09-01T00:00:00Z',
      unreadCount: unread,
    );

void main() {
  group('which pills are offered', () {
    test('only All when nothing else has anything', () {
      expect(availableChatListFilters([_conv('a', 'dm')]), [
        ChatListFilter.all,
      ]);
    });

    test('a tab joins once it has something in it', () {
      expect(
        availableChatListFilters(
          [_conv('a', 'dm'), _conv('g', 'group')],
          hasLocalShare: true,
          hasDrafts: true,
        ),
        [
          ChatListFilter.all,
          ChatListFilter.groups,
          ChatListFilter.localShare,
          ChatListFilter.drafts,
        ],
      );
    });

    test('Unread joins only while something is unread', () {
      expect(
        availableChatListFilters([_conv('a', 'dm', unread: 2)]),
        contains(ChatListFilter.unread),
      );
      expect(
        availableChatListFilters([_conv('a', 'dm')]),
        isNot(contains(ChatListFilter.unread)),
      );
    });

    test('Locked only while this phone has a locked chat', () {
      expect(
        availableChatListFilters([_conv('a', 'dm')], hasLocked: true),
        contains(ChatListFilter.locked),
      );
      expect(
        availableChatListFilters([_conv('a', 'dm')]),
        isNot(contains(ChatListFilter.locked)),
      );
    });
  });

  test('only Locked opens a page; the rest filter in place', () {
    expect(isChatListFilterAction(ChatListFilter.locked), isTrue);
    for (final f in ChatListFilter.values) {
      if (f == ChatListFilter.locked) continue;
      expect(isChatListFilterAction(f), isFalse, reason: '$f');
    }
  });

  test('Groups and Flock filter the list', () {
    final dms = [_conv('d', 'dm')];
    final channels = [
      _conv('g', 'group'),
      _conv('c', 'channel'),
      _conv('w', 'webhook'),
    ];
    final groups = unifiedConversations(
      dms: dms,
      channels: channels,
      filter: ChatListFilter.groups,
    );
    expect(groups.map((c) => c.id), unorderedEquals(['g', 'c']));
    final flock = unifiedConversations(
      dms: dms,
      channels: channels,
      filter: ChatListFilter.webhooks,
    );
    expect(flock.map((c) => c.id), ['w']);
  });

  test('Unread still filters the list', () {
    final rows = unifiedConversations(
      dms: [_conv('d', 'dm', unread: 1), _conv('e', 'dm')],
      channels: [_conv('g', 'group', unread: 2)],
      filter: ChatListFilter.unread,
    );
    expect(rows.map((c) => c.id), unorderedEquals(['d', 'g']));
  });
}
