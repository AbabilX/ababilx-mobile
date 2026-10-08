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
  Future<void> wholeHistoryProven(int newest) => app
      .read(feedSpanStoreProvider)
      .update(
        conv,
        (s) => s.add(
          FeedSpan(lowMs: 0, highMs: messageTimeMs(msg(newest)), done: true),
        ),
      );

  test('in a fully stored chat a bumped thread root is not where scrollback '
      'continues from', () async {
    final all = [
      for (var n = 1; n <= 300; n++) msg(n, threadCount: n == 5 ? 3 : 0),
    ];
    server.rows.addAll(all);
    server.activityMs[idOf(5)] = messageTimeMs(msg(999));
    await store().saveAll(all);
    await wholeHistoryProven(300);

    await app.open();
    // Message 5 came with the newest page. Drawn now, the next page would be
    // read from before IT, and 6..250 would never appear.
    expect(app.shown, ids(251, 300));

    await app.scrollBack(2);
    expect(app.shown, ids(151, 300));
    await app.scrollBack(10);
    expect(app.shown, ids(1, 300));
  });

  test('old history is taken as stored: no request per page', () async {
    historyStart = DateTime.now().toUtc().subtract(const Duration(days: 90));
    final all = [for (var n = 1; n <= 300; n++) msg(n)];
    server.rows.addAll(all);
    await store().saveAll(all);
    await wholeHistoryProven(300);
    app.chat.setActiveConversation(conv);

    await app.open();
    await app.scrollBack(4);
    await settle();

    expect(app.shown, ids(51, 300));
    expect(server.cursors, [null]);
  });

  test('history read before the newest page arrived is kept, read from the '
      'store, and healed behind the reader', () async {
    server.rows.addAll([for (var n = 1; n <= 200; n++) msg(n)]);
    // Message 70 never reached this phone.
    await store().saveAll([
      for (var n = 1; n <= 200; n++)
        if (n != 70) msg(n),
    ]);
    app.chat.setActiveConversation(conv);
    server.offline = true;
    await app.open();
    await app.scrollBack();
    expect(app.shown, ids(101, 200));

    // The network comes back and the newest page lands.
    server.offline = false;
    await app.chat.loadFeed(conv, force: true);
    // Nothing the reader was looking at is taken away.
    expect(app.shown, ids(101, 200));

    final asked = server.olderRequests;
    await app.scrollBack();
    // On screen from the store before any answer could have come back.
    expect(app.shown.first, idOf(50));
    expect(app.shown.contains(idOf(70)), isFalse);
    expect(server.olderRequests - asked, lessThanOrEqualTo(1));

    await settle();
    expect(app.shown, ids(50, 200));
    expect(await store().byId(idOf(70)), isNotNull);
  });

  test(
    'a copy the server blanked never replaces the one the phone holds',
    () async {
      final all = [for (var n = 1; n <= 120; n++) msg(n, revision: 1)];
      await store().saveAll(all);
      // Retention ran: the server kept the rows and emptied them.
      server.rows.addAll([
        for (var n = 1; n <= 120; n++)
          ChatMessage.fromJson({
            ...msg(n, revision: 9).toJson(),
            'body': '',
            'content_purged': true,
          }),
      ]);
      app.chat.setActiveConversation(conv);

      await app.open();
      await app.scrollBack(10);
      await settle();

      expect(app.shown, ids(1, 120));
      expect(
        app.feed.messages.every((m) => m.body.startsWith('body ')),
        isTrue,
      );
      expect((await store().byId(idOf(100)))!.body, 'body 100');
      expect((await store().byId(idOf(10)))!.body, 'body 10');
    },
  );
}
