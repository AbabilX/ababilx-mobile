import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/calls/screens/incoming_call_view.dart';

void main() {
  Widget host({
    required VoidCallback onDecline,
    required VoidCallback onAccept,
  }) => MaterialApp(
    home: Scaffold(
      body: IncomingCallView(
        peerName: 'Rahim Uddin',
        peerAvatar: null,
        onDecline: onDecline,
        onAccept: onAccept,
      ),
    ),
  );

  testWidgets('a ringing call shows the caller and the two answers', (
    tester,
  ) async {
    await tester.pumpWidget(host(onDecline: () {}, onAccept: () {}));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Rahim Uddin'), findsOneWidget);
    expect(find.text('AbabilX voice call'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('answering and declining reach their callbacks', (tester) async {
    var declined = 0;
    var accepted = 0;
    await tester.pumpWidget(
      host(onDecline: () => declined++, onAccept: () => accepted++),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Tap the circles, not the labels underneath them.
    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump();

    expect(accepted, 1);
    expect(declined, 1);
  });

  testWidgets('in-call controls stay off the ringing screen', (tester) async {
    await tester.pumpWidget(host(onDecline: () {}, onAccept: () {}));
    await tester.pump(const Duration(milliseconds: 300));

    // While it is still ringing there is nothing to mute or share.
    expect(find.text('Mute'), findsNothing);
    expect(find.text('Speaker'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });
}
