import 'package:ababilx/core/router/shell_bottom_bar/index.dart';
import 'package:ababilx/core/router/shell_bottom_bar/shell_pill_chrome.dart';
import 'package:ababilx/core/router/shell_bottom_bar/shell_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shell renders only the navigation capsule', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ShellBottomBar(
              tabs: const [messagesShellTab, callsShellTab],
              labelOf: (tab) => tab.labelKey,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ShellPillChrome), findsOneWidget);
  });
}
