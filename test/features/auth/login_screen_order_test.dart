import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/auth/data/auth_session.dart';
import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/auth/screens/login_screen.dart';
import 'package:ababilx/features/auth/widgets/onboarding_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOut extends AuthNotifier {
  int started = 0;

  @override
  Future<bool> build() async => false;

  @override
  Future<SignInOutcome> startNewChat() async {
    started++;
    return super.startNewChat();
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // User's rule (2026-10-20): all three, always, in this order.
  testWidgets('Start New Chat, then Google, then email', (tester) async {
    SharedPreferences.setMockInitialValues({
      OnboardingGate.preferenceKey: true,
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          authProvider.overrideWith(_SignedOut.new),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final labels = [
      'Start New Chat',
      'Sign in with Google',
      'Sign in with email and password',
    ];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
    expect(find.byType(FilledButton), findsOneWidget);
  });

  // User's call (2026-10-21): Google is offered BEFORE an account exists, so
  // choosing it (or backing out) leaves nothing behind on the server.
  testWidgets('Start New Chat asks about Google first, creates nothing yet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      OnboardingGate.preferenceKey: true,
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _SignedOut();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          authProvider.overrideWith(() => auth),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start New Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Keep your account safe?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Skip, start without an account'), findsOneWidget);
    expect(auth.started, 0);

    // Dismissed: still nothing.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Keep your account safe?'), findsNothing);
    expect(auth.started, 0);
  });
}
