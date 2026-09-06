import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/messages/message_e2ee/vault_gate_recovery_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    bool busy = false,
    String language = 'en',
    VoidCallback? recover,
    VoidCallback? fresh,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [appLanguageProvider.overrideWithValue(language)],
      child: MaterialApp(
        home: Scaffold(
          body: VaultGateRecoveryChoice(
            busy: busy,
            onRecover: recover ?? () {},
            onStartFresh: fresh ?? () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('offers recovery first without opening the keyboard', (
    tester,
  ) async {
    var recovered = 0;
    var fresh = 0;
    await show(tester, recover: () => recovered++, fresh: () => fresh++);
    expect(find.text('Restore your messages'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('I have a recovery code'));
    expect(recovered, 1);
    expect(fresh, 0);
    await tester.tap(find.text('Start fresh'));
    expect(fresh, 1);
  });

  testWidgets(
    'always offers both user choices without claiming code ownership',
    (tester) async {
      await show(tester);
      expect(find.text('We found your message backup'), findsNothing);
      expect(
        find.text('This account has no recovery-code backup.'),
        findsNothing,
      );
      expect(find.text('I have a recovery code'), findsOneWidget);
      expect(find.text('Start fresh'), findsOneWidget);
    },
  );

  testWidgets('prevents repeated actions while reset is open', (tester) async {
    var calls = 0;
    await show(
      tester,
      busy: true,
      recover: () => calls++,
      fresh: () => calls++,
    );
    await tester.tap(find.text('I have a recovery code'));
    await tester.tap(find.text('Start fresh'));
    expect(calls, 0);
  });

  testWidgets('supports Bangla and a small viewport with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show(tester, language: 'bn');
    expect(find.text('আপনার মেসেজ ফিরিয়ে আনুন'), findsOneWidget);
    await tester.ensureVisible(find.text('নতুনভাবে শুরু করুন'));
    expect(tester.takeException(), isNull);
  });
}
