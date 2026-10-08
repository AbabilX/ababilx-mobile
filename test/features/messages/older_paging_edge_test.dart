import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_row.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/feed_span_store.dart';
import 'package:ababilx/features/messages/data/local/feed_spans.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'older_paging_harness.dart';

void main() {
  late ChatLocalDb db;
  late FakeServer server;
  late ProviderContainer app;

  setUp(() {
    historyStart = recentHistoryStart();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    server = FakeServer();
    app = launch(db, server);
  });

  tearDown(() async {
    app.dispose();
    await db.close();
  });

  List<String> ids(int from, int to) => [
    for (var n = from; n <= to; n++) idOf(n),
  ];
  ChatMessageStore store() => ChatMessageStore(db);
  Future<void> stretch(FeedSpan span) =>
      app.read(feedSpanStoreProvider).update(conv, (s) => s.add(span));

  test(
    'a thread root bumped into the newest page waits for its place',
    () async {
      server.rows.addAll([
        for (var n = 1; n <= 120; n++) msg(n, threadCount: n == 5 ? 3 : 0),
      ]);
      // Message 5 got a reply a moment ago, so the server lists it first.
      server.activityMs[idOf(5)] = messageTimeMs(msg(999));

      await app.open();

      // Not at the top of the timeline with months missing under it.
      expect(app.shown, ids(72, 120));

      await app.scrollBack(10);
      expect(app.shown, ids(1, 120));
    },
  );

  test(
    'a cursor the server no longer holds does not end the history',
    () async {
      server.rows.addAll([for (var n = 1; n <= 120; n++) msg(n)]);
      await app.open();
      expect(app.shown, ids(71, 120));

      // The page's cursor message is deleted on the server; this phone was
      // not told. Asked from it, the server answers an empty page.
      server.rows.removeWhere((m) => m.id == idOf(71));
      await app.scrollBack(10);

      expect(app.shown, ids(1, 120));
    },
  );

  test(
    'a private chat, which the server no longer holds, reads the phone',
    () async {
      await store().saveAll([
        for (var n = 1; n <= 120; n++) msg(n, privateChat: true),
      ]);

      await app.open();
      await app.scrollBack(10);

      expect(app.shown, ids(1, 120));
      expect(server.olderRequests, 0);
    },
  );

  test('a stretch that outlived its rows is caught at the end', () async {
    server.rows.addAll([for (var n = 1; n <= 120; n++) msg(n)]);
    // The store lost everything below 71, but a stretch still says the
    // whole conversation is here.
    await store().saveAll([for (var n = 71; n <= 120; n++) msg(n)]);
    await stretch(
      FeedSpan(lowMs: 0, highMs: messageTimeMs(msg(120)), done: true),
    );

    await app.open();
    await app.scrollBack(10);

    expect(app.shown, ids(1, 120));
  });

  test('rows lost inside a stretch are fetched again, not skipped', () async {
    server.rows.addAll([for (var n = 1; n <= 200; n++) msg(n)]);
    // The stretch reaches back to 50; the store only has 151 and up.
    await store().saveAll([for (var n = 151; n <= 200; n++) msg(n)]);
    await stretch(
      FeedSpan(
        lowMs: messageTimeMs(msg(50)),
        highMs: messageTimeMs(msg(200)),
        cursor: idOf(50),
      ),
    );

    await app.open();
    await app.scrollBack(10);

    expect(app.shown, ids(1, 200));
  });

  test('a page drawn from disk is corrected in place afterwards', () async {
    const read = ChatDeliverySummary(
      targetedDevices: 1,
      deliveredDevices: 1,
      readDevices: 1,
    );
    // What the phone stored, before it stopped listening.
    await store().saveAll([for (var n = 1; n <= 300; n++) msg(n, revision: 1)]);
    await stretch(
      FeedSpan(lowMs: 0, highMs: messageTimeMs(msg(300)), done: true),
    );
    // What happened since: an edit on 220, a read receipt on 230.
    server.rows.addAll([
      for (var n = 1; n <= 300; n++)
        if (n == 220)
          msg(n, revision: 7).copyWith(body: 'edited')
        else if (n == 230)
          msg(n, revision: 1, delivery: read)
        else
          msg(n, revision: 1),
    ]);
    app.chat.setActiveConversation(conv);

    await app.open();
    await app.scrollBack();
    // On screen at once, from the store as it was.
    expect(app.shown, ids(201, 300));
    await settle();

    final byId = {for (final m in app.feed.messages) m.id: m};
    expect(byId[idOf(220)]!.body, 'edited');
    expect(byId[idOf(230)]!.delivery, read);
    expect(app.shown, ids(201, 300));
    expect((await store().byId(idOf(220)))!.body, 'edited');
    // One request for the page, none for rows that did not change.
    expect(server.olderRequests, 1);
  });

  test('while the chat is open, the next pages are stored ahead', () async {
    server.rows.addAll([for (var n = 1; n <= 400; n++) msg(n)]);
    app.chat.setActiveConversation(conv);

    await app.open();
    // The first step back has to ask the server: nothing is proven yet.
    await app.scrollBack();
    expect(app.shown, ids(301, 400));
    await settle();

    // Two more pages are already on the phone, so the next steps do not wait.
    expect(await store().byId(idOf(210)), isNotNull);
    final asked = server.olderRequests;
    final before = app.chat.loadMoreFeed(conv);
    await before;
    expect(app.shown, ids(251, 400));
    expect(app.feed.loadingMore, isFalse);
    expect(server.cursors.take(asked + 1).last, isNot(idOf(301)));
  });
}
