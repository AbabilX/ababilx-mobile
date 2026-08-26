import 'package:ababilx/features/messages/data/models/chat_connection.dart';
import 'package:ababilx/features/messages/new-message/new_message_people_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The screen puts this widget straight into `CustomScrollView.slivers`, so the
/// test has to as well — a box returned from a sliver slot only blows up once a
/// viewport tries to lay it out.
Widget host(List<ChatUserSummary> people) => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        NewMessagePeopleList(
          people: people,
          emptyTitle: 'No people available',
          emptyBody: 'Search above to find people.',
          onTap: (_) {},
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('an account with nobody to message still renders', (
    tester,
  ) async {
    await tester.pumpWidget(host(const []));
    expect(tester.takeException(), isNull);
    expect(find.text('No people available'), findsOneWidget);
  });

  testWidgets('people render as rows', (tester) async {
    await tester.pumpWidget(
      host(const [
        ChatUserSummary(userId: '1', name: 'Ada', canMessage: true),
        ChatUserSummary(userId: '2', name: 'Grace', canMessage: false),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('No people available'), findsNothing);
  });
}
