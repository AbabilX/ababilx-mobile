import 'dart:convert';

import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_local_migrations.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The V3 blob table, recreated by hand — it no longer exists in the schema,
/// which is exactly why the backfill has to be able to read it.
Future<void> _createLegacyBlobTable(ChatLocalDb db) => db.customStatement(
  'CREATE TABLE cached_message_feeds ('
  'conversation_id TEXT NOT NULL PRIMARY KEY, '
  'payload_json TEXT NOT NULL, '
  'updated_at_ms INTEGER NOT NULL)',
);

void main() {
  late ChatLocalDb db;

  setUp(() => db = ChatLocalDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'carries V3 blob history into message rows, then drops the table',
    () async {
      await _createLegacyBlobTable(db);
      await db.customStatement(
        'INSERT INTO cached_message_feeds VALUES (?, ?, ?)',
        [
          'c1',
          jsonEncode([
            {
              'id': 'm1',
              'conversation_id': 'c1',
              'user_id': 'u1',
              'body': 'older',
              'created_at': '2026-08-21T00:00:00Z',
            },
            {
              'id': 'm2',
              'conversation_id': 'c1',
              'user_id': 'u1',
              'body': 'newer',
              'created_at': '2026-08-22T00:00:00Z',
            },
          ]),
          0,
        ],
      );

      await backfillMessageRowsFromFeedBlobs(db);

      final migrated = await ChatMessageStore(db).page('c1');
      expect(migrated.map((m) => m.id), ['m1', 'm2']);
      expect(migrated.last.body, 'newer');

      final leftover = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = 'cached_message_feeds'",
          )
          .get();
      expect(leftover, isEmpty);
    },
  );

  test('a device with no V3 cache upgrades without error', () async {
    await backfillMessageRowsFromFeedBlobs(db);
    expect(await ChatMessageStore(db).page('c1'), isEmpty);
  });

  test('one corrupt blob does not block the rest', () async {
    await _createLegacyBlobTable(db);
    await db.customStatement(
      'INSERT INTO cached_message_feeds VALUES (?, ?, ?)',
      ['bad', 'not json at all', 0],
    );
    await db.customStatement(
      'INSERT INTO cached_message_feeds VALUES (?, ?, ?)',
      [
        'good',
        jsonEncode([
          {
            'id': 'm9',
            'conversation_id': 'good',
            'user_id': 'u1',
            'body': 'kept',
            'created_at': '2026-08-22T00:00:00Z',
          },
        ]),
        0,
      ],
    );

    await backfillMessageRowsFromFeedBlobs(db);

    expect((await ChatMessageStore(db).page('good')).single.id, 'm9');
  });
}
