import 'package:ababilx/core/router/router_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// `currentConfiguration.uri` is not the route on top after an imperative
/// push, and every group-call navigation guard was written against it: the
/// call screen stayed up after Leave, and the return-to-call banner drew over
/// the call it was offering to return to.

GoRouter _router() => GoRouter(
  initialLocation: '/messages',
  routes: [
    GoRoute(path: '/messages', builder: (_, _) => const Text('messages')),
    GoRoute(path: '/group-call', builder: (_, _) => const Text('call')),
  ],
);

void main() {
  testWidgets('reports the imperatively pushed route, unlike uri.path', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(currentRoutePath(router), '/messages');

    router.push('/group-call');
    await tester.pumpAndSettle();

    expect(currentRoutePath(router), '/group-call');
    // The trap itself, pinned: `push` carries the base uri through untouched,
    // so a guard written against it never sees the pushed screen.
    expect(router.routerDelegate.currentConfiguration.uri.path, '/messages');
  });

  testWidgets('follows a pop back down the stack', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.push('/group-call');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(currentRoutePath(router), '/messages');
  });

  testWidgets('follows go, which does rewrite the location', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/group-call');
    await tester.pumpAndSettle();

    expect(currentRoutePath(router), '/group-call');
  });
}
