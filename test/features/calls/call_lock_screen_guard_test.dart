import 'dart:async';

import 'package:ababilx/features/calls/widgets/call_lock_screen_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ababilx.app/call_lock_screen');
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  late List<Map<Object?, Object?>> reports;
  late Map<String, bool> nativeState;
  // Made inside a test body when needed: a Completer made in setUp completes
  // on the real zone, which a FakeAsync pump never runs.
  Completer<Map<String, bool>>? slowState;

  setUp(() {
    reports = [];
    nativeState = {'locked': false, 'overLock': false};
    slowState = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'state') return slowState?.future ?? nativeState;
          if (call.method == 'setCallState') {
            reports.add(Map.of(call.arguments as Map));
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> push(WidgetTester tester, Map<String, bool> state) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('changed', state),
        ),
        (_) {},
      );

  Widget app({required bool visible, bool live = true}) => MaterialApp(
    home: CallLockScreenGuard(
      callVisible: visible,
      callLive: live,
      child: Text(visible ? 'CALL' : 'PRIVATE'),
    ),
  );

  testWidgets(
    'behind the keyguard the app is left alone, so unlock never flashes',
    (tester) async {
      nativeState = {'locked': true, 'overLock': false};
      await tester.pumpWidget(app(visible: false, live: false));
      await tester.pump();
      expect(find.text('PRIVATE'), findsOneWidget);
    },
    variant: android,
  );

  testWidgets('an Accept handoff shows nothing but the call', (tester) async {
    nativeState = {'locked': true, 'overLock': true};
    await tester.pumpWidget(app(visible: false));
    await tester.pump();
    expect(find.text('PRIVATE'), findsNothing);
    await tester.pumpWidget(app(visible: true));
    expect(find.text('CALL'), findsOneWidget);
    await tester.pump();
    expect(reports.last, {'visible': true, 'live': true});
  }, variant: android);

  testWidgets(
    'a call leaving a locked screen is masked in that same frame',
    (tester) async {
      // Native has answered nothing yet: the call screen alone raised the flag.
      nativeState = {'locked': true, 'overLock': false};
      await tester.pumpWidget(app(visible: false));
      await tester.pump();
      await tester.pumpWidget(app(visible: true));
      await tester.pumpWidget(app(visible: false));
      expect(find.text('PRIVATE'), findsNothing);
      await tester.pump();
      expect(reports.last, {'visible': false, 'live': true});
    },
    variant: android,
  );

  testWidgets('native covering the app itself lets the mask go', (
    tester,
  ) async {
    nativeState = {'locked': true, 'overLock': true};
    await tester.pumpWidget(app(visible: false));
    await tester.pump();
    expect(find.text('PRIVATE'), findsNothing);
    await push(tester, {'locked': true, 'overLock': false});
    await tester.pump();
    expect(find.text('PRIVATE'), findsOneWidget);
  }, variant: android);

  testWidgets('ending a call on an unlocked phone never blanks it', (
    tester,
  ) async {
    await tester.pumpWidget(app(visible: true));
    await tester.pump();
    await tester.pumpWidget(app(visible: false, live: false));
    expect(find.text('PRIVATE'), findsOneWidget);
  }, variant: android);

  testWidgets('a native change wins over a stale startup reply', (
    tester,
  ) async {
    slowState = Completer<Map<String, bool>>();
    await tester.pumpWidget(app(visible: false));
    await push(tester, {'locked': true, 'overLock': true});
    slowState!.complete({'locked': false, 'overLock': false});
    await tester.pump();
    expect(find.text('PRIVATE'), findsNothing);
  }, variant: android);

  testWidgets(
    'off Android nothing is masked and nothing is sent',
    (tester) async {
      await tester.pumpWidget(app(visible: false));
      await push(tester, {'locked': true, 'overLock': true});
      await tester.pump();
      expect(find.text('PRIVATE'), findsOneWidget);
      expect(reports, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
