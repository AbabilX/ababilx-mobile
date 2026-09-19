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

  testWidgets('landscape hides Answer/Decline captions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(568, 320)),
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
    expect(find.text('Decline'), findsNothing);
    expect(find.text('Answer'), findsNothing);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
  });
}
