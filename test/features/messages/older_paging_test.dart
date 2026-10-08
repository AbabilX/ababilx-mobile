import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_row.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/feed_span_store.dart';
import 'package:ababilx/features/messages/data/local/feed_spans.dart';
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

  /// The phone holds [from]..[to], and a stretch says so.
  Future<void> proven(int from, int to, {bool done = false}) async {
    await ChatMessageStore(
      db,
    ).saveAll([for (var n = from; n <= to; n++) msg(n)]);
    await app
        .read(feedSpanStoreProvider)
        .update(
          conv,
          (s) => s.add(
            FeedSpan(
              lowMs: done ? 0 : messageTimeMs(msg(from)),
              highMs: messageTimeMs(msg(to)),
              cursor: done ? '' : idOf(from),
              done: done,
            ),
          ),
        );
  }

  test(
    'history the phone holds is read from the phone, not the server',
    () async {
      server.rows.addAll([for (var n = 1; n <= 300; n++) msg(n)]);
      await proven(1, 300, done: true);

      await app.open();
      await app.scrollBack(4);

      expect(app.shown, ids(51, 300));
      // The one request was the newest page at open.
      expect(server.cursors, [null]);
      expect(app.feed.loadingMore, isFalse);
    },
  );

  test('the end of history is confirmed with the server, once', () async {
    server.rows.addAll([for (var n = 1; n <= 120; n++) msg(n)]);
    await proven(1, 120, done: true);

    await app.open();
    await app.scrollBack(10);

    expect(app.shown, ids(1, 120));
    expect(app.feed.hasMore, isFalse);
    final asked = server.olderRequests;
    expect(asked, greaterThan(0));

    await app.chat.loadMoreFeed(conv);
    expect(server.olderRequests, asked);
  });

  test(
    'messages missed while away are walked through, never skipped',
    () async {
      // The phone last saw message 100; two hundred more arrived since.
      server.rows.addAll([for (var n = 1; n <= 300; n++) msg(n)]);
      await proven(1, 100, done: true);

      await app.open();

      // The newest page does not reach what the phone holds, so the old rows
      // are not drawn straight under it as if nothing were missing.
      expect(app.shown, ids(251, 300));

      await app.scrollBack(20);

      expect(app.shown, ids(1, 300));
      // Four pages cross the hole (250..101); the last one touches what was
      // already held and everything below comes off the disk.
      expect(server.olderRequests, lessThanOrEqualTo(6));
      expect(server.cursors.whereType<String>().take(4), [
        idOf(251),
        idOf(201),
        idOf(151),
        idOf(101),
      ]);
    },
  );

  test(
    'a first walk is fetched once; the next launch reads the disk',
    () async {
      server.rows.addAll([for (var n = 1; n <= 120; n++) msg(n)]);

      await app.open();
      await app.scrollBack(10);
      expect(app.shown, ids(1, 120));
      expect(server.olderRequests, 2);

      app.dispose();
      server.cursors.clear();
      app = launch(db, server);
      await app.open();
      await app.scrollBack(2);

      expect(app.shown, ids(1, 120));
      expect(server.olderRequests, 0);

      // Only standing on the first message is the server asked anything: one
      // request, to confirm it really is the first.
      await app.scrollBack(5);
      expect(app.feed.hasMore, isFalse);
      expect(server.olderRequests, 1);
    },
  );

  test('a restore walk proves the whole conversation', () async {
    server.rows.addAll([for (var n = 1; n <= 230; n++) msg(n)]);

    await app.chat.restoreConversation(conv);
    final spans = await app.read(feedSpanStoreProvider).read(conv);
    expect(spans.spans.single.done, isTrue);
    expect(spans.at(messageTimeMs(msg(1))), isNotNull);

    server.cursors.clear();
    await app.open();
    await app.scrollBack(3);

    expect(app.shown, ids(31, 230));
    expect(server.cursors, [null]);
  });

  test('two callers asking at once share one load', () async {
    server.rows.addAll([for (var n = 1; n <= 300; n++) msg(n)]);
    await proven(1, 300, done: true);
    await app.open();

    final first = app.chat.loadMoreFeed(conv);
    final second = app.chat.loadMoreFeed(conv);

    expect(identical(first, second), isTrue);
    await first;
    expect(app.shown, ids(201, 300));
  });
}
