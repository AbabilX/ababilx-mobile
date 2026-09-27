import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/messages/chat-pins/chat_pin_search.dart';
import 'package:ababilx/features/messages/chat-pins/chat_pins_provider.dart';
import 'package:ababilx/features/messages/chat-pins/pinned_messages_screen.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/group-member-permissions/group_admin_api.dart';
import 'package:ababilx/features/messages/group-pins/group_pins_provider.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:ababilx/features/messages/providers/pinned_message_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChatMessage _msg(String id, String body, String at) => ChatMessage.fromJson({
  'id': id,
  'conversation_id': 'g1',
  'user_id': 'alice',
  'user_name': 'Alice',
  'body': body,
  'created_at': at,
});

const _group = ChatConversation(
  id: 'g1',
  teamId: '',
  scope: 'personal',
  type: 'group',
  name: 'Team',
  createdBy: 'alice',
  createdAt: '2026-01-01T00:00:00Z',
);

class _Chat extends ChatNotifier {
  @override
  ChatState build() => const ChatState(currentUserId: 'me', channels: [_group]);
}

final _shared = _msg('shared', 'Group rules', '2026-09-20T00:00:00Z');
final _both = _msg('both', 'Meeting at 5', '2026-09-21T00:00:00Z');
final _mine = _msg('mine', 'My note', '2026-09-22T00:00:00Z');

List<Override> _overrides({bool canPin = false}) => [
  appLanguageProvider.overrideWithValue('en'),
  chatProvider.overrideWith(_Chat.new),
  pinnedMessagesProvider.overrideWith(
    (ref, id) async => [
      ChatPinnedMessage(message: _mine, pinnedAt: ''),
      ChatPinnedMessage(message: _both, pinnedAt: ''),
    ],
  ),
  groupPinsProvider.overrideWith(
    (ref, id) async => GroupPinsPage(
      pins: [
        GroupPin(message: _both, pinnedAt: ''),
        GroupPin(message: _shared, pinnedAt: ''),
      ],
      canPin: canPin,
    ),
  ),
];

void main() {
  test('a group merges its shared pins with the caller\'s own', () async {
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);
    container.listen(chatPinsProvider('g1'), (_, _) {});
    await container.read(pinnedMessagesProvider('g1').future);
    await container.read(groupPinsProvider('g1').future);
    final view = container.read(chatPinsProvider('g1')).value!;
    expect(view.entries.map((e) => e.message.id), ['mine', 'both', 'shared']);
    final byId = {for (final e in view.entries) e.message.id: e};
    expect((byId['both']!.mine, byId['both']!.everyone), (true, true));
    expect((byId['shared']!.mine, byId['shared']!.everyone), (false, true));
    // A member cannot take the group's pin down; only their own.
    expect(view.canUnpin(byId['shared']!), isFalse);
    expect(view.canUnpin(byId['mine']!), isTrue);
  });

  testWidgets('the Pins page lists group pins, marked, unpinnable by admins', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(
          home: PinnedMessagesScreen(conversationId: 'g1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 Pinned Messages'), findsOneWidget);
    expect(find.text('Group rules'), findsOneWidget);
    expect(find.text('Pinned for everyone'), findsNWidgets(2));

    await tester.longPress(find.text('Group rules'));
    await tester.pumpAndSettle();
    expect(find.text('Go to message'), findsWidgets);
    expect(find.text('Unpin message'), findsNothing);
  });

  testWidgets('search in the header narrows pins and hides Unpin all', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(
          home: PinnedMessagesScreen(conversationId: 'g1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unpin all'), findsOneWidget);

    await tester.tap(find.byTooltip('Search pins'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin all'), findsNothing);
    await tester.enterText(find.byType(TextField), 'meeting');
    await tester.pumpAndSettle();
    expect(find.text('Meeting at 5'), findsOneWidget);
    expect(find.text('Group rules'), findsNothing);
    expect(find.text('My note'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No pinned messages match'), findsOneWidget);

    await tester.tap(find.byTooltip('Search pins'));
    await tester.pumpAndSettle();
    expect(find.text('Group rules'), findsOneWidget);
    expect(find.text('Unpin all'), findsOneWidget);
  });

  test('a pin matches on its sender or its text', () {
    expect(pinMatchesQuery(_shared, 'alice'), isTrue);
    expect(pinMatchesQuery(_shared, 'RULES'), isTrue);
    expect(pinMatchesQuery(_shared, 'meeting'), isFalse);
  });
}
