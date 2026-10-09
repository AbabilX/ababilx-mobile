import 'package:ababilx/core/theme/theme_mode_provider.dart';
import 'package:ababilx/features/messages/chat-list/you-sheet/index.dart';
import 'package:ababilx/features/messages/chat-list/you-sheet/you_menu.dart';
import 'package:ababilx/features/messages/chat-list/you-sheet/you_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('YouSheet renders 4-item grid and does not render signout', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: YouSheet(),
          ),
        ),
      ),
    );

    // Verify 4 grid items exist
    expect(find.byType(YouMenuItem), findsNWidgets(4));
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);

    // Sign out must not be present in this sheet
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('Tapping Theme cycles themeMode in YouMenu', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: YouMenu(),
          ),
        ),
      ),
    );

    expect(container.read(themeModeProvider), AppThemeMode.system);

    // Tap Theme item
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    // Verify theme mode cycled
    expect(container.read(themeModeProvider), AppThemeMode.light);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.dark);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.lightsOut);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.system);
  });
}
