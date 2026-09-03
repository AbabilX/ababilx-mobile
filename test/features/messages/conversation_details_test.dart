import 'package:ababilx/features/messages/chat-details/conversation_details_screen.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _group() => const ChatConversation(
  id: 'g1',
  teamId: '',
  scope: 'personal',
  type: 'group',
  name: 'Full Team',
  createdAt: '2026-09-01T10:00:00Z',
  myRole: 'admin',
  memberCount: 3,
);

class _Notifier extends ChatNotifier {
  @override
  ChatState build() => ChatState(currentUserId: 'me', channels: [_group()]);

  @override
  Future<List<ChatMember>> listChannelMembers(String channelId) async => [
    const ChatMember(
      userId: 'me',
      name: 'Me',
      joinedAt: '2026-09-01T10:00:00Z',
      role: 'admin',
    ),
    const ChatMember(
      userId: 'u2',
      name: 'Badhon',
      joinedAt: '2026-09-01T10:00:00Z',
    ),
  ];
}

void main() {
  testWidgets('group details renders and tears down cleanly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_Notifier.new)],
        child: const MaterialApp(
          home: ConversationDetailsScreen(conversationId: 'g1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Full Team'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);

    // Deactivate the whole tree: an inherited dependency taken from the wrong
    // context shows up here as the framework's _dependents.isEmpty assert.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('every sheet the details screen opens survives teardown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_Notifier.new)],
        child: const MaterialApp(
          home: ConversationDetailsScreen(conversationId: 'g1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pencil → group info.
    await tester.tap(find.byTooltip('Edit group'));
    await tester.pumpAndSettle();
    expect(find.text('Group info'), findsOneWidget);
    Navigator.of(tester.element(find.text('Group info'))).pop();
    await tester.pumpAndSettle();

    // Add members (below the fold in a lazy list).
    await tester.scrollUntilVisible(find.text('Add members'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add members'));
    // Not pumpAndSettle: with no fake repo the connections refresh never
    // answers, so the sheet's spinner would spin for the whole timeout.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Search people'), findsOneWidget);
    Navigator.of(tester.element(find.text('Search people'))).pop();
    await tester.pump(const Duration(milliseconds: 400));

    // A member row.
    await tester.tap(find.text('Badhon'));
    await tester.pumpAndSettle();
    expect(find.text('View profile'), findsOneWidget);
    Navigator.of(tester.element(find.text('View profile'))).pop();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
