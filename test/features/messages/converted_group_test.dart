import 'package:ababilx/features/messages/chat-details/conversation_details_screen.dart';
import 'package:ababilx/features/messages/chat-details/group_permissions.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'no_pins_override.dart';

/// A workspace channel after the server's migration 0145: same id, now an
/// ordinary personal group with no team. Its admins are whoever the migration
/// wrote down; its switches kept the strict 'admin' default channels had.
ChatConversation converted({
  String myRole = 'admin',
  String roles = 'admin',
  String createdBy = 'someone-else',
}) => ChatConversation(
  id: 'converted',
  teamId: '',
  scope: 'personal',
  type: 'group',
  name: 'General',
  createdBy: createdBy,
  createdAt: '2026-01-01T00:00:00Z',
  myRole: myRole,
  editInfoRole: roles,
  addMembersRole: roles,
);

class _Notifier extends ChatNotifier {
  _Notifier(this.group);
  final ChatConversation group;

  @override
  ChatState build() => ChatState(currentUserId: 'me', channels: [group]);

  @override
  Future<List<ChatMember>> listChannelMembers(String channelId) async =>
      const [];
}

Future<void> openDetails(WidgetTester tester, ChatConversation group) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        noPinsOverride,
        chatProvider.overrideWith(() => _Notifier(group)),
      ],
      child: const MaterialApp(
        home: ConversationDetailsScreen(conversationId: 'converted'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('a converted workspace group answers to its own roles', () {
    test('its admin may do everything', () {
      final perms = GroupPermissions(converted());
      expect(perms.canManage, isTrue);
      expect(perms.canEditInfo, isTrue);
      expect(perms.canAddMembers, isTrue);
    });

    test('a plain member follows the switches', () {
      final locked = GroupPermissions(converted(myRole: 'member'));
      expect(locked.canManage, isFalse);
      expect(locked.canEditInfo, isFalse);
      expect(locked.canAddMembers, isFalse);

      final open = GroupPermissions(
        converted(myRole: 'member', roles: 'member'),
      );
      expect(open.canManage, isFalse);
      expect(open.canEditInfo, isTrue);
      expect(open.canAddMembers, isTrue);
    });

    // There is no team input left to pass: leading a workspace, this one or
    // any other, cannot widen what a member may do in a group.
    test('who created it grants nothing', () {
      final creator = converted(myRole: 'member', createdBy: 'me');
      expect(GroupPermissions(creator).canManage, isFalse);
    });
  });

  group('an update reply never demotes the admin who made it', () {
    ProviderContainer containerWith(ChatConversation group) {
      final container = ProviderContainer(
        overrides: [
          noPinsOverride,
          chatProvider.overrideWith(() => _Notifier(group)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a rename answered without my_role keeps the role', () {
      final container = containerWith(converted());
      container
          .read(chatProvider.notifier)
          .upsertChannel(
            ChatConversation.fromJson({
              'id': 'converted',
              'scope': 'personal',
              'type': 'group',
              'name': 'Renamed',
              'created_at': '2026-01-01T00:00:00Z',
            }),
          );
      final row = container.read(chatProvider).channels.single;
      expect(row.name, 'Renamed');
      expect(row.myRole, 'admin');
    });

    test('a role the server does report still lands', () {
      final container = containerWith(converted());
      container
          .read(chatProvider.notifier)
          .upsertChannel(
            ChatConversation.fromJson({
              'id': 'converted',
              'scope': 'personal',
              'type': 'group',
              'name': 'General',
              'created_at': '2026-01-01T00:00:00Z',
              'my_role': 'member',
            }),
          );
      expect(container.read(chatProvider).channels.single.myRole, 'member');
    });
  });

  testWidgets('its admin edits all of the group info, not only the name', (
    tester,
  ) async {
    await openDetails(tester, converted());
    await tester.tap(find.byTooltip('Edit group'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Group name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Description'), findsOneWidget);
    expect(find.text('Add banner'), findsOneWidget);
  });

  testWidgets('a plain member of an admins-only group gets no pencil', (
    tester,
  ) async {
    await openDetails(tester, converted(myRole: 'member'));
    expect(find.byTooltip('Edit group'), findsNothing);
  });
}
