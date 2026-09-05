import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/shared/widgets/app_toast.dart';

void main() {
  testWidgets('a toast appears and clears itself', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    showAppToast(ctx, 'Forwarded to 2 chats');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Forwarded to 2 chats'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Forwarded to 2 chats'), findsNothing);
  });

  // The reason this is an overlay entry and not a SnackBar: the forward flow
  // shows it and then immediately pops the picker that showed it.
  testWidgets('a toast outlives the route that showed it', (tester) async {
    late BuildContext rootCtx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            rootCtx = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    late BuildContext pushedCtx;
    unawaited(
      Navigator.of(rootCtx).push<void>(
        MaterialPageRoute(
          builder: (context) {
            pushedCtx = context;
            return const Scaffold(body: Text('picker'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    showAppToast(pushedCtx, 'Forwarded to 1 chat');
    Navigator.of(pushedCtx).pop();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('picker'), findsNothing);
    expect(find.text('Forwarded to 1 chat'), findsOneWidget);
  });

  testWidgets('a second toast replaces the first', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    showAppToast(ctx, 'first');
    await tester.pump(const Duration(milliseconds: 100));
    showAppToast(ctx, 'second');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
