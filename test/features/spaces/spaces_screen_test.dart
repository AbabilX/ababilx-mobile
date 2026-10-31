import 'dart:async';

import 'package:ababilx/features/spaces/data/space_failure.dart';
import 'package:ababilx/features/spaces/data/space_models.dart';
import 'package:ababilx/features/spaces/ui/spaces_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spaces_fakes.dart';

final offline = DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);

class _HangBackend extends FakeBackend {
  final gate = Completer<List<SpaceSummary>>();
  @override
  Future<List<SpaceSummary>> listSpaces() => gate.future;
}

Future<List<String>> pump(
  WidgetTester t,
  FakeBackend b, {
  MemoryKv? kv,
  ThemeData? theme,
}) async {
  final opened = <String>[];
  await t.pumpWidget(
    ProviderScope(
      overrides: spacesOverrides(b, kv ?? MemoryKv()),
      child: MaterialApp(
        theme: theme,
        home: SpacesScreen(onOpenChannel: (s, c) => opened.add('$s/$c')),
      ),
    ),
  );
  return opened;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  testWidgets('first load shows a skeleton, not a blank screen', (t) async {
    final b = _HangBackend();
    await pump(t, b);
    await t.pump();
    expect(find.byKey(const Key('spaces-skeleton')), findsOneWidget);
    b.gate.complete(const []);
    await settle(t);
  });

  testWidgets('service down and nothing saved: error with Retry that works', (
    t,
  ) async {
    final b = FakeBackend()..listError = const SpaceUnavailable();
    await pump(t, b);
    await settle(t);
    expect(find.byKey(const Key('spaces-error')), findsOneWidget);
    expect(
      find.text(spaceFailureCopy(SpaceFailure.unavailable).title),
      findsOneWidget,
    );
    b
      ..listError = null
      ..spaces = [nethex]
      ..trees['s1'] = sampleTree('s1');
    await t.tap(find.text('Try again'));
    await settle(t);
    expect(find.byKey(const Key('spaces-error')), findsNothing);
    expect(find.text('admin-chat'), findsOneWidget);
  });

  testWidgets('no spaces: empty state offers create and join', (t) async {
    await pump(t, FakeBackend());
    await settle(t);
    expect(find.byKey(const Key('spaces-empty')), findsOneWidget);
    expect(find.text('Create a space'), findsOneWidget);
    expect(find.text('Join with a link'), findsOneWidget);
  });

  testWidgets('rail + channels in categories, Discord-like', (t) async {
    final b = FakeBackend()
      ..spaces = [nethex, panda]
      ..trees['s1'] = sampleTree('s1');
    final opened = await pump(t, b);
    await settle(t);
    expect(find.byKey(const Key('space-rail')), findsOneWidget);
    expect(find.text('NetHex'), findsWidgets);
    expect(find.text('general'), findsOneWidget);
    expect(find.text('Admin & Management'), findsOneWidget);
    expect(find.text('Devs'), findsOneWidget);
    expect(find.byKey(const Key('channel-lock-c1')), findsOneWidget);
    expect(find.byKey(const Key('channel-lock-c2')), findsNothing);
    expect(find.byKey(const Key('channel-announce-c2')), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // mention badge on backend
    await t.tap(find.text('backend'));
    expect(opened, ['s1/c3']);
  });

  testWidgets('collapsing a category hides its read channels only', (t) async {
    final b = FakeBackend()
      ..spaces = [nethex]
      ..trees['s1'] = sampleTree('s1');
    await pump(t, b);
    await settle(t);
    await t.tap(find.text('Admin & Management'));
    await settle(t);
    expect(find.text('admin-chat'), findsNothing);
    expect(find.text('notify'), findsOneWidget, reason: 'unread stays visible');
    await t.tap(find.text('Admin & Management'));
    await settle(t);
    expect(find.text('admin-chat'), findsOneWidget);
  });

  testWidgets('offline with a saved copy: content stays, banner + retry', (
    t,
  ) async {
    final kv = MemoryKv();
    final ok = FakeBackend()
      ..spaces = [nethex]
      ..trees['s1'] = sampleTree('s1');
    await pump(t, ok, kv: kv);
    await settle(t);
    await t.pumpWidget(const SizedBox());

    final down = FakeBackend()
      ..listError = offline
      ..treeError = offline;
    await pump(t, down, kv: kv);
    await settle(t);
    expect(find.text('admin-chat'), findsOneWidget);
    expect(find.byKey(const Key('spaces-banner')), findsWidgets);
    expect(find.textContaining('saved copy'), findsWidgets);
  });

  testWidgets('switching space in the rail loads its channels', (t) async {
    final b = FakeBackend()
      ..spaces = [nethex, panda]
      ..trees['s1'] = sampleTree('s1')
      ..trees['s2'] = SpaceTree.fromJson('s2', {
        'space': {'name': 'Panda'},
        'channels': [
          {'id': 'p1', 'name': 'bamboo'},
        ],
      });
    await pump(t, b);
    await settle(t);
    await t.tap(find.byKey(const Key('rail-s2')));
    await settle(t);
    expect(find.text('bamboo'), findsOneWidget);
    expect(find.text('admin-chat'), findsNothing);
  });

  testWidgets('channel list failing alone keeps the rail usable', (t) async {
    final b = FakeBackend()
      ..spaces = [nethex, panda]
      ..treeError = const SpaceUnavailable();
    await pump(t, b);
    await settle(t);
    expect(find.byKey(const Key('space-rail')), findsOneWidget);
    expect(find.byKey(const Key('channels-error')), findsOneWidget);
  });

  testWidgets('renders in dark theme too', (t) async {
    final b = FakeBackend()
      ..spaces = [nethex]
      ..trees['s1'] = sampleTree('s1');
    await pump(t, b, theme: ThemeData(brightness: Brightness.dark));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('general'), findsOneWidget);
  });
}
