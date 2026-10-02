import 'package:ababilx/core/router/home_tab_position.dart';
import 'package:ababilx/core/router/shell_bottom_bar/index.dart';
import 'package:ababilx/core/router/shell_bottom_bar/shell_tabs.dart';
import 'package:ababilx/core/router/swipe_tab_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _tabs = [messagesShellTab, callsShellTab];

GoRouter _router() {
  Page<void> pager(int i) => MaterialPage<void>(
    key: const ValueKey('pager'),
    child: SwipeTabPager(
      index: i,
      routes: const ['/messages', '/calls'],
      pages: const [
        Center(child: Text('Chats page')),
        Text('Talks page'),
      ],
    ),
  );
  return GoRouter(
    initialLocation: '/messages',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: child),
              Align(
                alignment: Alignment.bottomCenter,
                child: ShellBottomBar(
                  tabs: _tabs,
                  selectedIndex: shellTabIndex(_tabs, state.matchedLocation),
                  labelOf: (t) => t.labelKey,
                  onSelect: (i) => context.go(_tabs[i].route),
                ),
              ),
            ],
          ),
        ),
        routes: [
          GoRoute(path: '/messages', pageBuilder: (_, _) => pager(0)),
          GoRoute(path: '/calls', pageBuilder: (_, _) => pager(1)),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('dragging across the capsule changes tab', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final bar = find.byType(ShellBottomBar);
    final c = tester.getCenter(bar);
    final g = await tester.startGesture(c - const Offset(40, 0));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Mid-drag the indicator is between tabs and the page has moved with it.
    expect(homeTabPosition.value, greaterThan(0.2));
    await g.up();
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/calls');
    expect(homeTabPosition.value, 1.0);
  });
}
