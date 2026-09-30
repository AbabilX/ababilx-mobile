import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ababilx/core/router/swipe_tab_active.dart';
import 'package:ababilx/core/router/swipe_tab_pager.dart';

const _routes = ['/chats', '/talks'];

/// The same shape as the app: a shell, both tabs building one keyed page, and
/// a third tab that is an ordinary page.
GoRouter _router(String initial, List<State> built) {
  Page<void> pager(GoRouterState state, int index) => MaterialPage<void>(
    key: const ValueKey('pager'),
    child: SwipeTabPager(
      index: index,
      routes: _routes,
      pages: [
        _Probe(label: 'Chats page', built: built),
        _Probe(label: 'Talks page', built: built),
      ],
    ),
  );
  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (_, _, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/chats', pageBuilder: (_, s) => pager(s, 0)),
          GoRoute(path: '/talks', pageBuilder: (_, s) => pager(s, 1)),
          GoRoute(path: '/wall', builder: (_, _) => const Text('Wall page')),
        ],
      ),
    ],
  );
}

/// A tall vertical list, so a vertical drag has something to scroll.
class _Probe extends StatefulWidget {
  const _Probe({required this.label, required this.built});
  final String label;
  final List<State> built;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with SwipeTabVisits {
  final visits = <String>[];

  @override
  void initState() {
    super.initState();
    widget.built.add(this);
  }

  @override
  void onTabShown() => visits.add('shown');

  @override
  void onTabHidden() => visits.add('hidden');

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text(widget.label),
      for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('row $i')),
    ],
  );
}

Future<GoRouter> _pump(
  WidgetTester tester,
  String initial, [
  List<State>? b,
]) async {
  final router = _router(initial, b ?? []);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('swiping left on Chats lands on Talks and moves the route', (
    tester,
  ) async {
    final router = await _pump(tester, '/chats');
    expect(find.text('Talks page'), findsNothing);

    await tester.fling(find.text('Chats page'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Talks page'), findsOneWidget);
    expect(find.text('Chats page'), findsNothing);
    expect(_location(router), '/talks');
  });

  testWidgets('swiping right on Talks comes back to Chats', (tester) async {
    final router = await _pump(tester, '/talks');

    await tester.fling(find.text('Talks page'), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Chats page'), findsOneWidget);
    expect(_location(router), '/chats');
  });

  testWidgets('a short drag springs back and leaves the route alone', (
    tester,
  ) async {
    final router = await _pump(tester, '/chats');

    await tester.drag(find.text('Chats page'), const Offset(-60, 0));
    await tester.pumpAndSettle();

    expect(find.text('Chats page'), findsOneWidget);
    expect(_location(router), '/chats');
  });

  testWidgets('scrolling the list does not change tab', (tester) async {
    final router = await _pump(tester, '/chats');

    await tester.fling(find.text('row 2'), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();

    expect(_location(router), '/chats');
    expect(find.text('Talks page'), findsNothing);
  });

  testWidgets('both pages are built once and kept across swipes and taps', (
    tester,
  ) async {
    final built = <State>[];
    final router = await _pump(tester, '/chats', built);
    final pager = tester.state(find.byType(SwipeTabPager));
    // The neighbour is ready before the first swipe, not built under it.
    expect(built, hasLength(2));

    router.go('/talks');
    await tester.pumpAndSettle();
    await tester.fling(find.text('Talks page'), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(_location(router), '/chats');
    expect(tester.state(find.byType(SwipeTabPager)), same(pager));
    expect(built, hasLength(2));
    expect(built.every((s) => s.mounted), isTrue);

    router.go('/wall');
    await tester.pumpAndSettle();
    expect(find.text('Wall page'), findsOneWidget);
    expect(built.any((s) => s.mounted), isFalse);
  });

  testWidgets('a page hears shown / hidden once per visit', (tester) async {
    final built = <State>[];
    final router = await _pump(tester, '/chats', built);
    final chats = built[0] as _ProbeState;
    final talks = built[1] as _ProbeState;
    expect(chats.visits, isEmpty);
    expect(talks.visits, isEmpty);

    await tester.fling(find.text('Chats page'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(chats.visits, ['hidden']);
    expect(talks.visits, ['shown']);

    router.go('/chats');
    await tester.pumpAndSettle();
    expect(chats.visits, ['hidden', 'shown']);
    expect(talks.visits, ['shown', 'hidden']);
  });
}
