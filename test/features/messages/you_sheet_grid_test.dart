import 'package:ababilx/core/theme/theme_mode_provider.dart';
import 'package:ababilx/features/messages/chat-list/you-sheet/index.dart';
import 'package:ababilx/features/messages/chat-list/you-sheet/you_away.dart';
import 'package:ababilx/features/messages/chat-list/you-sheet/you_menu.dart';
import 'package:ababilx/features/messages/chat-list/you-sheet/you_menu_item.dart';
import 'package:ababilx/features/privacy-mode/privacy_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('YouSheet renders the 8 quick actions in order, no sign out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_away],
        child: const MaterialApp(home: Scaffold(body: YouSheet())),
      ),
    );

    // Toggles first, places second; Settings last.
    final labels = tester
        .widgetList<YouMenuItem>(find.byType(YouMenuItem))
        .map((item) => item.label)
        .toList();
    expect(labels, [
      'Away',
      'Privacy',
      'System',
      'People',
      'Scan QR',
      'Devices',
      'Local Share',
      'Settings',
    ]);

    // Sign out must not be present in this sheet
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('Tapping Theme cycles themeMode and updates label in YouMenu', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: [_away]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: YouMenu())),
      ),
    );

    expect(container.read(themeModeProvider), AppThemeMode.system);
    expect(find.text('System'), findsOneWidget);

    // Tap System -> Light
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.light);
    expect(find.text('Light'), findsOneWidget);

    // Tap Light -> Dark
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.dark);
    expect(find.text('Dark'), findsOneWidget);

    // Tap Dark -> Lights Out
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.lightsOut);
    expect(find.text('Lights Out'), findsOneWidget);

    // Tap Lights Out -> System
    await tester.tap(find.text('Lights Out'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.system);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('Privacy lights up while privacy mode is on', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyModeProvider.overrideWith(_OnPrivacy.new), _away],
        child: const MaterialApp(home: Scaffold(body: YouMenu())),
      ),
    );
    final items = tester.widgetList<YouMenuItem>(find.byType(YouMenuItem));
    expect(items.firstWhere((i) => i.label == 'Privacy').active, isTrue);
    expect(items.firstWhere((i) => i.label == 'Away').active, isFalse);
  });
}

class _OnPrivacy extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

/// The real one opens the socket and asks the server.
final _away = awayProvider.overrideWith(_Away.new);

class _Away extends AwayNotifier {
  @override
  bool build() => false;
}
