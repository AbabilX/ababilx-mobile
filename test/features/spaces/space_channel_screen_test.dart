import 'package:ababilx/features/spaces/channel/space_channel_screen.dart';
import 'package:ababilx/features/spaces/data/space_failure.dart';
import 'package:ababilx/features/spaces/data/space_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spaces_fakes.dart';

final offline = DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);

Future<void> pump(WidgetTester t, FakeBackend b, {MemoryKv? kv}) async {
  b.trees['s1'] = sampleTree('s1');
  await t.pumpWidget(
    ProviderScope(
      overrides: spacesOverrides(b, kv ?? MemoryKv()),
      child: const MaterialApp(
        home: SpaceChannelScreen(spaceId: 's1', channelId: 'c3'),
      ),
    ),
  );
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  testWidgets('header names the channel and says it is not E2EE', (t) async {
    await pump(t, FakeBackend());
    await settle(t);
    expect(find.text('backend'), findsOneWidget);
    expect(find.text('Not end-to-end encrypted'), findsOneWidget);
    expect(find.byKey(const Key('channel-empty')), findsOneWidget);
  });

  testWidgets('messages render with author', (t) async {
    final b = FakeBackend()
      ..channelMessages = [
        SpaceMessage(
          id: 'm1',
          body: 'ship it',
          authorName: 'Murad',
          createdAt: DateTime(2026, 10, 31, 9, 5),
        ),
      ];
    await pump(t, b);
    await settle(t);
    expect(find.text('ship it'), findsOneWidget);
    expect(find.text('Murad'), findsOneWidget);
  });

  testWidgets('load failure with nothing saved: error + retry', (t) async {
    final b = FakeBackend()..messagesError = const SpaceUnavailable();
    await pump(t, b);
    await settle(t);
    expect(
      find.text(spaceFailureCopy(SpaceFailure.unavailable).title),
      findsOneWidget,
    );
    b
      ..messagesError = null
      ..channelMessages = [const SpaceMessage(id: 'm1', body: 'back')];
    await t.tap(find.text('Try again'));
    await settle(t);
    expect(find.text('back'), findsOneWidget);
  });

  testWidgets('send: appears, and a failure keeps it with tap-to-retry', (
    t,
  ) async {
    final b = FakeBackend()..sendError = offline;
    await pump(t, b);
    await settle(t);
    await t.enterText(find.byType(TextField), 'hello space');
    await t.tap(find.byKey(const Key('space-send')));
    await settle(t);
    expect(find.text('hello space'), findsOneWidget);
    expect(find.textContaining('Not sent'), findsOneWidget);
    expect(find.text('hello space').evaluate().length, 1);

    b.sendError = null;
    await t.tap(find.textContaining('Not sent'));
    await settle(t);
    expect(find.textContaining('Not sent'), findsNothing);
    expect(b.sent, ['hello space']);
  });

  testWidgets('composer clears after queuing, ignores blank', (t) async {
    final b = FakeBackend();
    await pump(t, b);
    await settle(t);
    await t.enterText(find.byType(TextField), '   ');
    await t.tap(find.byKey(const Key('space-send')));
    await settle(t);
    expect(b.sent, isEmpty);
    await t.enterText(find.byType(TextField), 'ok');
    await t.tap(find.byKey(const Key('space-send')));
    await settle(t);
    expect(b.sent, ['ok']);
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('offline with saved messages: shows them + banner', (t) async {
    final kv = MemoryKv();
    await pump(
      t,
      FakeBackend()
        ..channelMessages = [const SpaceMessage(id: 'm1', body: 'saved one')],
      kv: kv,
    );
    await settle(t);
    await t.pumpWidget(const SizedBox());
    await pump(t, FakeBackend()..messagesError = offline, kv: kv);
    await settle(t);
    expect(find.text('saved one'), findsOneWidget);
    expect(find.byKey(const Key('spaces-banner')), findsOneWidget);
  });
}
