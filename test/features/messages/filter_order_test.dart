import 'package:ababilx/features/messages/chat-list/filter_order.dart';
import 'package:ababilx/features/messages/chat_list_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const all = [
    ChatListFilter.all,
    ChatListFilter.unread,
    ChatListFilter.groups,
    ChatListFilter.localShare,
  ];

  test('no saved order keeps the default', () {
    expect(applyFilterOrder(all, const []), all);
  });

  test('saved order wins, All stays first, unknown pills go last', () {
    expect(applyFilterOrder(all, ['localShare', 'groups']), [
      ChatListFilter.all,
      ChatListFilter.localShare,
      ChatListFilter.groups,
      ChatListFilter.unread,
    ]);
  });
}
