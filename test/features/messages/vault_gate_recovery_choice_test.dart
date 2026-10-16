import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/messages/message_e2ee/vault_gate_recovery_choice.dart';
import 'package:ababilx/shared/onboarding/onboarding_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const code = 'Use your recovery code';
  const fresh = 'Continue without restoring';

  Future<void> show(
    WidgetTester tester, {
    bool busy = false,
    String language = 'en',
    VoidCallback? startFresh,
    VoidCallback? wrongAccount,
    Widget? backupOption,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [appLanguageProvider.overrideWithValue(language)],
      child: MaterialApp(
        home: Scaffold(
          body: VaultGateRecoveryChoice(
            busy: busy,
            onStartFresh: startFresh ?? () {},
            onWrongAccount: wrongAccount,
            backupOption: backupOption,
          ),
        ),
      ),
    ),
  );

  testWidgets('no recovery code: starting fresh is the only card', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Restore your account'), findsOneWidget);
    expect(find.text(code), findsNothing);
    expect(find.byType(OnboardingOptionCard), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a local backup sits above starting fresh', (tester) async {
    await show(tester, backupOption: const Text('backup card'));
    final backup = tester.getTopLeft(find.text('backup card')).dy;
    expect(backup, lessThan(tester.getTopLeft(find.text(fresh)).dy));
    expect(find.text(code), findsNothing);
  });

  testWidgets('starting fresh is confirmed first, and can be cancelled', (
    tester,
  ) async {
    var started = 0;
    await show(tester, startFresh: () => started++);
    await tester.tap(find.text(fresh));
    await tester.pumpAndSettle();
    expect(find.text('Continue without restoring?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(started, 0);
    await tester.tap(find.text(fresh));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(started, 1);
  });

  testWidgets('prevents actions while busy', (tester) async {
    var calls = 0;
    await show(tester, busy: true, startFresh: () => calls++);
    await tester.tap(find.text(fresh));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
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
    expect(find.text('আপনার অ্যাকাউন্ট ফিরিয়ে আনুন'), findsOneWidget);
    await tester.ensureVisible(find.text('ফিরিয়ে না এনে চালিয়ে যান'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wrong account has a quiet line at the foot', (tester) async {
    var signedOut = 0;
    await show(tester, wrongAccount: () => signedOut++);
    final line = find.text('Wrong account? Sign in with another');
    expect(find.byType(TextButton), findsOneWidget);
    await tester.tap(line);
    expect(signedOut, 1);
  });

  testWidgets('reached from Settings, the sign-out line is not offered', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Wrong account? Sign in with another'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
