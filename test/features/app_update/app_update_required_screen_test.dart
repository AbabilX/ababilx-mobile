import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/app-update/app_update_info.dart';
import 'package:ababilx/features/app-update/app_update_required_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The gate draws this in MaterialApp.builder, ABOVE the navigator, where
  // there is no Overlay. Anything on it that needs one (selectable text, a
  // tooltip) would throw on first use; this renders it exactly there.
  testWidgets('renders above the navigator', (tester) async {
    const info = AppUpdateInfo(
      latestVersion: '5.3.0',
      latestBuild: 31,
      updateAvailable: true,
      updateRequired: true,
      whatsNew: 'Calls stay up at the ear\nTimer keeps counting',
      storeUrl: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLanguageProvider.overrideWithValue('en')],
        child: MaterialApp(
          home: const Scaffold(body: Text('app underneath')),
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              child!,
              const AppUpdateRequiredScreen(info: info),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Update required'), findsOneWidget);
    expect(find.textContaining('5.3.0'), findsOneWidget);
    expect(find.textContaining('Timer keeps counting'), findsOneWidget);

    await tester.longPress(find.textContaining('Timer keeps counting'));
    await tester.tap(find.text('Update'));
    await tester.pump();
    // An empty store link cannot open anything: the screen says so.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Could not open the store'), findsOneWidget);
  });
}
