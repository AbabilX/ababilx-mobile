import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/messages/chat-details/conversation_details_screen.dart';
import 'package:ababilx/features/messages/chat-details/group_members_screen.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'no_pins_override.dart';

const _group = ChatConversation(
  id: 'g1',
  teamId: '',
  scope: 'personal',
  type: 'group',
  name: 'Team',
  createdAt: '2026-09-01T10:00:00Z',
  myRole: 'member',
);

const _names = ['Alice', 'Badhon', 'Chitra', 'Dipu', 'Eshan', 'Farhan'];

final _roster = [
  for (final (i, name) in _names.indexed)
    ChatMember(
      userId: 'u$i',
      name: name,
      joinedAt: '2026-09-01T10:00:00Z',
      role: i == 0 ? 'admin' : 'member',
    ),
];

class _Notifier extends ChatNotifier {
  _Notifier(this.members);
  final List<ChatMember> members;

  @override
  ChatState build() => const ChatState(currentUserId: 'u1', channels: [_group]);

  @override
  Future<List<ChatMember>> listChannelMembers(String channelId) async =>
      members;
}

Future<void> _pump(WidgetTester tester, List<ChatMember> members) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const ConversationDetailsScreen(conversationId: 'g1'),
      ),
      GoRoute(
        path: '/messages/:id/members',
        builder: (_, state) => GroupMembersScreen(
          conversationId: state.pathParameters['id']!,
          initialMembers: state.extra as List<ChatMember>? ?? const [],
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWithValue('en'),
        noPinsOverride,
        noGroupPinsOverride,
        chatProvider.overrideWith(() => _Notifier(members)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('details shows four members, then See all opens everyone', (
    tester,
  ) async {
    await _pump(tester, _roster);
    await tester.ensureVisible(find.text('See all members'));
    await tester.pumpAndSettle();
    for (final name in _names.take(4)) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Eshan'), findsNothing);
    expect(find.text('Farhan'), findsNothing);

    await tester.tap(find.text('See all members'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupMembersScreen), findsOneWidget);
    expect(find.text('6 members'), findsOneWidget);
    for (final name in _names) {
      expect(find.text(name), findsOneWidget);
    }

    // Search lives in the header, top right; the field replaces the title.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Search members'));
    await tester.pumpAndSettle();
    expect(find.text('6 members'), findsNothing);
    await tester.enterText(find.byType(TextField), 'far');
    await tester.pumpAndSettle();
    expect(find.text('Farhan'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No members found'), findsOneWidget);

    // Close clears the query and brings the title back.
    await tester.tap(find.byTooltip('Search members'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('6 members'), findsOneWidget);
    expect(find.text('Farhan'), findsOneWidget);
  });

  testWidgets('four or fewer members draw no See all row', (tester) async {
    await _pump(tester, _roster.take(4).toList());
    await tester.ensureVisible(find.text('Dipu'));
    await tester.pumpAndSettle();
    expect(find.text('See all members'), findsNothing);
  });
}
