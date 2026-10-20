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
    test('quick views always sit on the row, like Home', () {
      expect(availableChatListFilters([_conv('a', 'dm')]), [
        ChatListFilter.all,
        ChatListFilter.groups,
        ChatListFilter.webhooks,
        ChatListFilter.localShare,
        ChatListFilter.drafts,
      ]);
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

  test('quick-view pills are actions, not list filters', () {
    for (final f in [
      ChatListFilter.groups,
      ChatListFilter.webhooks,
      ChatListFilter.localShare,
      ChatListFilter.drafts,
      ChatListFilter.locked,
    ]) {
      expect(isChatListFilterAction(f), isTrue);
      expect(matchesChatListFilter(_conv('g', 'group'), f), isFalse);
    }
    expect(isChatListFilterAction(ChatListFilter.all), isFalse);
    expect(isChatListFilterAction(ChatListFilter.unread), isFalse);
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
