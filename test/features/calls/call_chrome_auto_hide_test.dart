import 'package:ababilx/features/calls/widgets/call_chrome_auto_hide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('audio-only (disabled) keeps chrome visible past idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CallChromeAutoHide(
            enabled: false,
            hideAfter: Duration(milliseconds: 50),
            child: Text('chrome'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('chrome'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });

  testWidgets('stage chrome hides after idle, tap reveals again', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CallChromeAutoHide(
            enabled: true,
            hideAfter: Duration(milliseconds: 50),
            fade: Duration.zero,
            child: Center(child: Text('chrome')),
          ),
        ),
      ),
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );

    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    // Empty corner — not the chrome label — hits the stage catcher.
    await tester.tapAt(const Offset(12, 12));
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });

  testWidgets('tap while visible hides chrome immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CallChromeAutoHide(
            enabled: true,
            hideAfter: Duration(seconds: 30),
            fade: Duration.zero,
            child: Center(child: Text('chrome')),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(12, 12));
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
  });
}
