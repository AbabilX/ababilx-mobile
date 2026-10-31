import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_sidebar_slice.dart';
import 'package:ababilx/features/messages/providers/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _dm(String id) => ChatConversation.fromJson({
  'id': id,
  'type': 'dm',
  'name': id,
});

void main() {
  final base = ChatState(
    dms: [_dm('a')],
    channels: const [],
    currentUserId: 'me',
  );

  test('a timeline, thread or search change leaves the list slice equal', () {
    final slice = chatSidebarSlice(base);
    for (final next in [
      base.copyWith(activeConversationId: 'a'),
      base.copyWith(feeds: {'a': const ChatFeed()}),
      base.copyWith(threadRepliesByRoot: {'r': const []}),
      base.copyWith(sending: true),
      base.copyWith(searchQuery: 'hi', searchLoading: true),
      base.copyWith(wsConnected: true),
    ]) {
      expect(chatSidebarSlice(next), slice);
    }
  });

  test('a sidebar change makes the slice differ', () {
    final slice = chatSidebarSlice(base);
    expect(chatSidebarSlice(base.copyWith(dms: [_dm('a')])), isNot(slice));
    expect(chatSidebarSlice(base.copyWith(channels: [_dm('g')])), isNot(slice));
    expect(chatSidebarSlice(base.copyWith(sidebarLoading: true)), isNot(slice));
    expect(chatSidebarSlice(base.copyWith(currentUserId: 'x')), isNot(slice));
  });
}
