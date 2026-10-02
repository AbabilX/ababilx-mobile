import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/onboarding/permissions/permission_intro.dart';
import 'package:ababilx/features/onboarding/permissions/permission_intro_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> show(
    WidgetTester tester,
    List<IntroPermission> rows,
    VoidCallback onDone,
  ) => tester.pumpWidget(
    ProviderScope(
      overrides: [appLanguageProvider.overrideWithValue('en')],
      child: MaterialApp(
        home: Scaffold(
          body: PermissionIntroPage(rows: rows, onDone: onDone),
        ),
      ),
    ),
  );

  testWidgets('one row per missing permission, Not now and Next', (
    tester,
  ) async {
    await show(tester, IntroPermission.values, () {});
    expect(find.text('Allow permissions'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Microphone'), findsOneWidget);
    expect(find.text('Photos and videos'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Not now remembers the answer and asks nothing', (tester) async {
    var done = 0;
    await show(tester, const [IntroPermission.microphone], () => done++);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(await PermissionIntro.answer(), PermissionIntro.answeredLater);
    expect(await PermissionIntro.shouldShow(), isFalse);
  });
}
