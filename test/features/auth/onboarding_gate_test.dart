import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/auth/widgets/onboarding_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> show(WidgetTester tester, {String language = 'en'}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLanguageProvider.overrideWithValue(language)],
        child: const MaterialApp(
          home: OnboardingGate(
            child: Scaffold(body: Text('Login destination')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('continues to login and remembers introduction on remount', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await show(tester);
    expect(find.text('Your people.\nAlways close.'), findsOneWidget);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await show(tester);
    expect(find.text('Login destination'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('Bangla large text on a small phone keeps action accessible', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show(tester, language: 'bn');
    expect(find.text('আপন মানুষ।\nসবসময় কাছে।'), findsOneWidget);
    await tester.ensureVisible(find.text('শুরু করুন'));
    await tester.tap(find.text('শুরু করুন'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
