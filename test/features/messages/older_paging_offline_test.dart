import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
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

  test(
    'opened offline, history pages from the store with no request',
    () async {
      await ChatMessageStore(
        db,
      ).saveAll([for (var n = 1; n <= 120; n++) msg(n)]);
      server.offline = true;

      await app.open();
      expect(app.shown, ids(71, 120));
      await app.scrollBack(10);

      expect(app.shown, ids(1, 120));
      // Only the newest-page attempt at open; never a wait before a page.
      expect(server.olderRequests, 0);
      expect(app.feed.hasMore, isFalse);
    },
  );

  test('the network dying mid-scroll falls back to the store', () async {
    server.rows.addAll([for (var n = 1; n <= 200; n++) msg(n)]);
    await ChatMessageStore(db).saveAll([for (var n = 1; n <= 200; n++) msg(n)]);

    await app.open();
    expect(app.shown, ids(151, 200));
    server.offline = true;
    await app.scrollBack(10);

    expect(app.shown, ids(1, 200));
    // One failed attempt, then the store for the rest of the session.
    expect(server.olderRequests, 1);
  });
}
