import 'package:ababilx/features/calls/network/call_network_quality.dart';
import 'package:ababilx/features/calls/widgets/call_network_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    callNetworkQuality.value = CallNetworkLevel.unknown;
    callVideoHeld.value = false;
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: CallNetworkBadge())),
  );

  testWidgets('nothing is drawn before the call has a reading', (tester) async {
    await pump(tester);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the label follows the level', (tester) async {
    await pump(tester);
    callNetworkQuality.value = CallNetworkLevel.good;
    await tester.pump();
    expect(find.text('Good network'), findsOneWidget);
    callNetworkQuality.value = CallNetworkLevel.poor;
    await tester.pump();
    expect(find.text('Poor network'), findsOneWidget);
  });

  testWidgets('a held camera is named even while the voice path reads good', (
    tester,
  ) async {
    await pump(tester);
    callNetworkQuality.value = CallNetworkLevel.good;
    callVideoHeld.value = true;
    await tester.pump();
    expect(find.text('Weak network · video paused'), findsOneWidget);
    expect(find.text('Good network'), findsNothing);
    callVideoHeld.value = false;
    await tester.pump();
    expect(find.text('Good network'), findsOneWidget);
  });
}
