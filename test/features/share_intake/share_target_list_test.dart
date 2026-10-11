import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/chat-recipient-picker/chat_recipient_list.dart';
import 'package:ababilx/features/messages/chat-recipient-picker/chat_recipient_target.dart';

ChatConversation dm(String id, String peer) => ChatConversation(
  id: id,
  teamId: '',
  scope: 'personal',
  type: 'dm',
  createdAt: '',
  peerUserId: 'u-$id',
  peerUserName: peer,
);

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

List<ChatRecipientTarget> recipients(List<ChatConversation> conversations) =>
    conversations
        .map(
          (conversation) =>
              ChatRecipientTarget.conversation(conversation, 'me'),
        )
        .toList();

void main() {
  testWidgets('empty target list explains itself instead of rendering blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ChatRecipientList(
          recent: const [],
          groups: const [],
          contacts: const [],
          selected: const {},
          onToggle: (_) {},
          enabled: true,
          recentLabel: 'Recent chats',
          groupsLabel: 'Groups',
          contactsLabel: 'Contacts',
          emptyLabel: 'No recipients found',
        ),
      ),
    );

    expect(find.text('No recipients found'), findsOneWidget);
  });

  testWidgets('tapping a row reports the conversation id', (tester) async {
    final tapped = <ChatRecipientTarget>[];
    await tester.pumpWidget(
      host(
        ChatRecipientList(
          recent: recipients([dm('c1', 'Murad'), dm('c2', 'Alif')]),
          groups: const [],
          contacts: const [],
          selected: const {'conversation:c2'},
          onToggle: tapped.add,
          enabled: true,
          recentLabel: 'Recent chats',
          groupsLabel: 'Groups',
          contactsLabel: 'Contacts',
          emptyLabel: 'No recipients found',
        ),
      ),
    );

    expect(find.text('Murad'), findsOneWidget);
    expect(find.text('Alif'), findsOneWidget);
    // The selected row draws the filled check, the other the empty circle.
    expect(find.byType(HugeIcon), findsOneWidget);

    await tester.tap(find.text('Murad'));
    expect(tapped.single.id, 'c1');
  });

  testWidgets('rows do not respond while a send is in flight', (tester) async {
    final tapped = <ChatRecipientTarget>[];
    await tester.pumpWidget(
      host(
        ChatRecipientList(
          recent: recipients([dm('c1', 'Murad')]),
          groups: const [],
          contacts: const [],
          selected: const {},
          onToggle: tapped.add,
          enabled: false,
          recentLabel: 'Recent chats',
          groupsLabel: 'Groups',
          contactsLabel: 'Contacts',
          emptyLabel: 'No recipients found',
        ),
      ),
    );

    await tester.tap(find.text('Murad'));
    expect(tapped, isEmpty);
  });
}
