import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/calls/screens/incoming_call_view.dart';

void main() {
  Widget host({
    required VoidCallback onDecline,
    required VoidCallback onAccept,
  }) => MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(
        body: IncomingCallView(
          peerName: 'Rahim Uddin',
          peerAvatar: null,
          onDecline: onDecline,
          onAccept: onAccept,
        ),
      ),
    ),
  );

  testWidgets('a ringing call shows the caller and the two answers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(onDecline: () {}, onAccept: () {}));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Rahim Uddin'), findsOneWidget);
    expect(find.text('Incoming call…'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    // "Answer", not "Accept" — the word every phone dialler uses.
    expect(find.text('Answer'), findsOneWidget);
  });

  testWidgets('answering and declining reach their callbacks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var declined = 0;
    var accepted = 0;
    await tester.pumpWidget(
      host(onDecline: () => declined++, onAccept: () => accepted++),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump();

    expect(accepted, 1);
    expect(declined, 1);
  });

  testWidgets('in-call controls stay off the ringing screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(onDecline: () {}, onAccept: () {}));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mute'), findsNothing);
    expect(find.text('Speaker'), findsNothing);
    expect(find.text('Screen Share'), findsNothing);
  });

  testWidgets('Decline and Answer sit where the reference app puts them', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(onDecline: () {}, onAccept: () {}));
    await tester.pump(const Duration(milliseconds: 300));

    final decline = tester.getCenter(find.byIcon(Icons.call_end_rounded));
    final answer = tester.getCenter(find.byIcon(Icons.call_rounded));
    // IncomingCallScreen.PortraitButtons: 64dp side padding, 78dp seats,
    // Decline left and Answer right with a weighted spacer between. Each seat
    // is centred over its label, as in Compose, so a label wider than the
    // seat moves it inward a little.
    expect(decline.dx, inInclusiveRange(64 + 39, 64 + 39 + 20));
    expect(
      answer.dx,
      inInclusiveRange(size.width - 64 - 39 - 20, size.width - 64 - 39),
    );
    expect(decline.dy, answer.dy);
    // 24dp bottom padding under a 6dp gap and the label.
    expect(decline.dy, greaterThan(size.height - 140));
    expect(decline.dy, lessThan(size.height - 60));
    final declineSeat = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.call_end_rounded),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(declineSeat, const Size(78, 78));
  });

  testWidgets('landscape puts the pair in one labelled row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(844, 390)),
          child: Scaffold(
            body: IncomingCallView(
              peerName: 'Rahim Uddin',
              peerAvatar: null,
              onDecline: () {},
              onAccept: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    final decline = tester.getCenter(find.byIcon(Icons.call_end_rounded));
    final answer = tester.getCenter(find.byIcon(Icons.call_rounded));
    expect(decline.dy, answer.dy);
    // Two labelled seats 45dp apart (the reference app's LandscapeButtons).
    expect(answer.dx - decline.dx, inInclusiveRange(78 + 45, 78 + 45 + 40));
  });

  Widget withExtras({
    ValueChanged<String>? onMessage,
    Future<void> Function()? onSilence,
    Size size = const Size(390, 844),
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IncomingCallView(
          peerName: 'Rahim Uddin',
          peerAvatar: null,
          onDecline: () {},
          onAccept: () {},
          onDeclineWithMessage: onMessage,
          onSilence: onSilence,
        ),
      ),
    ),
  );

  testWidgets('Message opens the replies and a pick declines with it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <String>[];
    var silenced = 0;
    await tester.pumpWidget(
      withExtras(onMessage: sent.add, onSilence: () async => silenced++),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump();
    expect(find.text('Decline with message'), findsOneWidget);
    // Choosing words should not happen over a shouting ringtone.
    expect(silenced, 1);

    await tester.tap(find.text("I'll call you back soon."));
    await tester.pump();
    expect(sent, ["I'll call you back soon."]);
  });

  testWidgets('a written reply is sent as typed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <String>[];
    await tester.pumpWidget(withExtras(onMessage: sent.add));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Driving, 10 min  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Decline and send'));
    await tester.pump();
    expect(sent, ['Driving, 10 min']);
  });

  testWidgets('closing the replies returns to the ringing screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <String>[];
    await tester.pumpWidget(withExtras(onMessage: sent.add));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump();
    await tester.tap(find.text('Decline with message'));
    await tester.tapAt(const Offset(195, 100));
    await tester.pump();
    expect(find.text('Decline with message'), findsNothing);
    expect(sent, isEmpty);
  });

  testWidgets('Silence quiets the ring once and says so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var silenced = 0;
    await tester.pumpWidget(withExtras(onSilence: () async => silenced++));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.notifications_off_outlined));
    await tester.pump();
    // Now shown as already quiet, and a second press does nothing.
    await tester.tap(
      find.byIcon(Icons.notifications_off_rounded),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(silenced, 1);
    expect(find.text('Silenced'), findsOneWidget);
    expect(find.text('Incoming call…'), findsNothing);
  });

  testWidgets('no conversation, no Message button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(withExtras(onSilence: () async {}));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Message'), findsNothing);
    expect(find.text('Silence'), findsOneWidget);
  });

  testWidgets('a short phone keeps the caller clear of the buttons', (
    tester,
  ) async {
    const size = Size(360, 640);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      withExtras(onMessage: (_) {}, onSilence: () async {}, size: size),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    final status = tester.getBottomLeft(find.text('Incoming call…'));
    final message = tester.getTopLeft(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    expect(status.dy, lessThan(message.dy));
  });
}
