import 'package:ababilx/features/messages/data/models/chat_connection.dart';
import 'package:ababilx/features/messages/new-message/new_message_handle_results.dart';
import 'package:ababilx/features/messages/new-message/new_message_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget field(TextEditingController controller, {required bool handle}) =>
    MaterialApp(
      home: Scaffold(
        body: NewMessageSearch(
          controller: controller,
          focusNode: FocusNode(),
          hintText: handle ? 'username' : 'Name, username or email',
          helper: handle ? 'Type their full username.' : null,
          handle: handle,
          onChanged: (_) {},
        ),
      ),
    );

Widget results(String query, List<ChatUserSummary> people) => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(
      slivers: [
        NewMessageHandleResults(
          query: query,
          searching: false,
          error: '',
          people: people,
          noneTitle: 'No one has @$query',
          noneBody: 'Check the spelling.',
          onTap: (_) {},
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('username mode shows a grey @ that is not part of the text', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(field(controller, handle: true));
    expect(find.text('@'), findsOneWidget);
    expect(find.text('Type their full username.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '@ra him');
    expect(controller.text, 'rahim');
    expect(find.text('@'), findsOneWidget);
  });

  testWidgets('normal mode has no @ and keeps spaces', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(field(controller, handle: false));
    expect(find.text('@'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Ada L');
    expect(controller.text, 'Ada L');
  });

  testWidgets('a short handle says nothing yet', (tester) async {
    await tester.pumpWidget(results('ra', const []));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No one has'), findsNothing);
  });

  testWidgets('a full handle with no match says so', (tester) async {
    await tester.pumpWidget(results('rahim', const []));
    expect(find.text('No one has @rahim'), findsOneWidget);
  });

  testWidgets('a match is drawn as a row', (tester) async {
    await tester.pumpWidget(
      results('rahim', const [
        ChatUserSummary(
          userId: '1',
          name: 'Rahim',
          username: 'rahim',
          canMessage: true,
        ),
      ]),
    );
    expect(find.text('Rahim'), findsOneWidget);
    expect(find.text('@rahim'), findsOneWidget);
  });
}
