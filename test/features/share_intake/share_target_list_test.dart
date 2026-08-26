import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/share_intake/share-target/share_target_list.dart';

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

void main() {
  testWidgets('empty target list explains itself instead of rendering blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ShareTargetList(
          conversations: const [],
          currentUserId: 'me',
          selected: const {},
          onToggle: (_) {},
          enabled: true,
        ),
      ),
    );

    expect(find.textContaining('No conversations to share into'), findsOneWidget);
  });

  testWidgets('tapping a row reports the conversation id', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        ShareTargetList(
          conversations: [dm('c1', 'Murad'), dm('c2', 'Alif')],
          currentUserId: 'me',
          selected: const {'c2'},
          onToggle: tapped.add,
          enabled: true,
        ),
      ),
    );

    expect(find.text('Murad'), findsOneWidget);
    expect(find.text('Alif'), findsOneWidget);
    // The selected row draws the filled check, the other the empty circle.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

    await tester.tap(find.text('Murad'));
    expect(tapped, ['c1']);
  });

  testWidgets('rows do not respond while a send is in flight', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        ShareTargetList(
          conversations: [dm('c1', 'Murad')],
          currentUserId: 'me',
          selected: const {},
          onToggle: tapped.add,
          enabled: false,
        ),
      ),
    );

    await tester.tap(find.text('Murad'));
    expect(tapped, isEmpty);
  });
}
