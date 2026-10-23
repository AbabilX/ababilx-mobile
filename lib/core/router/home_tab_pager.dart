import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calls/screens/calls_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/messages/screens/messages_screen.dart';
import '../../features/settings/appearance/home_tab_setting.dart';
import 'shell_bottom_bar/shell_tab_order.dart';
import 'shell_bottom_bar/shell_tabs.dart';
import 'swipe_tab_pager.dart';

/// The page both routes build. The key is what makes it one page: the
/// navigator updates a page whose key it already holds rather than replacing
/// it, so switching tabs moves the pager instead of rebuilding it.
Page<void> homeTabPage(GoRouterState state) => MaterialPage<void>(
  key: const ValueKey('home-tab-pager'),
  name: state.path,
  child: _HomePager(route: state.matchedLocation),
);

/// Home, Chats and Talks in the order the user arranged the bar in: swiping follows
/// that order, and so does the page the route names.
class _HomePager extends ConsumerWidget {
  const _HomePager({required this.route});

  final String route;

  static const _screens = {
    '/home': HomeScreen(),
    '/messages': MessagesScreen(),
    '/calls': CallsScreen(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = applyTabOrder(
      ref.watch(shownShellTabsProvider),
      ref.watch(shellTabOrderProvider),
    );
    final routes = [for (final t in tabs) t.route];
    return SwipeTabPager(
      index: shellTabIndex(tabs, route),
      routes: routes,
      pages: [for (final r in routes) _screens[r]!],
    );
  }
}
