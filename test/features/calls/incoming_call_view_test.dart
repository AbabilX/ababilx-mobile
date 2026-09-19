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

  testWidgets('Decline and Answer are a large close pair, not edge-spread', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(onDecline: () {}, onAccept: () {}));
    await tester.pump(const Duration(milliseconds: 300));

    final decline = tester.getCenter(find.byIcon(Icons.call_end_rounded));
    final answer = tester.getCenter(find.byIcon(Icons.call_rounded));
    final gap = answer.dx - decline.dx;
    // Diameter ~92–112 + gap ~48–72 → centers ~140–185; still well inside
    // the frame (not spaceBetween to the edges).
    expect(gap, lessThan(200));
    expect(gap, greaterThan(130));
    expect(decline.dx, greaterThan(size.width * 0.18));
    expect(answer.dx, lessThan(size.width * 0.82));
    // Lifted above the bottom edge (bottom inset + ~56–88).
    expect(decline.dy, lessThan(size.height - 100));
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
