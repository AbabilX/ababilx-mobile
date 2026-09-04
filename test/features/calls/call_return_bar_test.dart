import 'package:ababilx/features/calls/widgets/call_return_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget bar) => MaterialApp(home: Scaffold(body: bar));

  testWidgets('shows who the call is with and what it is doing', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(CallReturnBar(title: 'Tanvir', status: () => '02:07', onTap: () {})),
    );

    expect(find.text('Tanvir'), findsOneWidget);
    expect(find.text('02:07'), findsOneWidget);
  });

  testWidgets('a ticking bar re-reads its status without a parent rebuild', (
    tester,
  ) async {
    var seconds = 0;
    await tester.pumpWidget(
      host(
        CallReturnBar(
          title: 'Tanvir',
          status: () => '00:0$seconds',
          ticking: true,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('00:00'), findsOneWidget);

    seconds = 1;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    // Stop the clock so the test does not leave a pending timer.
    await tester.pumpWidget(
      host(CallReturnBar(title: 'Tanvir', status: () => '00:01', onTap: () {})),
    );
  });

  testWidgets('a still bar starts no timer', (tester) async {
    var reads = 0;
    await tester.pumpWidget(
      host(
        CallReturnBar(
          title: 'Design',
          status: () {
            reads++;
            return '3 in call';
          },
          onTap: () {},
        ),
      ),
    );
    final afterFirstBuild = reads;
    await tester.pump(const Duration(seconds: 3));
    expect(reads, afterFirstBuild);
  });

  testWidgets('tapping it returns to the call', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        CallReturnBar(
          title: 'Tanvir',
          status: () => 'Reconnecting…',
          alerting: true,
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('Tanvir'));
    expect(taps, 1);
  });
}
