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
    test('DMs only, all read: no row at all, not a lone All', () {
      expect(availableChatListFilters([_conv('a', 'dm')]), isEmpty);
    });

    test('each pill appears only while something is behind it', () {
      expect(
        availableChatListFilters([_conv('a', 'dm', unread: 2)]),
        [ChatListFilter.all, ChatListFilter.unread],
      );
      expect(
        availableChatListFilters([_conv('a', 'dm'), _conv('g', 'group')]),
        [ChatListFilter.all, ChatListFilter.groups],
      );
      expect(
        availableChatListFilters([
          _conv('a', 'dm', unread: 1),
          _conv('c', 'channel'),
          _conv('w', 'webhook'),
        ]),
        ChatListFilter.values,
      );
    });
  });

  test('Groups holds groups and channels, never a feed or a DM', () {
    final rows = unifiedConversations(
      dms: [_conv('d', 'dm')],
      channels: [
        _conv('g', 'group'),
        _conv('c', 'channel'),
        _conv('w', 'webhook'),
      ],
      filter: ChatListFilter.groups,
    );
    expect(rows.map((c) => c.id), unorderedEquals(['g', 'c']));
  });

  test('Webhooks holds feeds only', () {
    final rows = unifiedConversations(
      dms: [_conv('d', 'dm')],
      channels: [_conv('g', 'group'), _conv('w', 'webhook')],
      filter: ChatListFilter.webhooks,
    );
    expect(rows.map((c) => c.id), ['w']);
  });
}
