import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChatLocalDb db;

  setUp(() => db = ChatLocalDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('V4 to V5 adds attachment tables and keeps message rows', () async {
    await db.customStatement(
      'INSERT INTO cached_messages '
      '(id, conversation_id, created_at_ms, payload_json, search_text) '
      "VALUES ('m1', 'c1', 1, '{}', '')",
    );
    await db.customStatement('DROP TABLE attachment_refs');
    await db.customStatement('DROP TABLE attachment_blobs');

    await db.migration.onUpgrade(db.createMigrator(), 4, 5);

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('attachment_blobs', 'attachment_refs')",
        )
        .get();
    expect(tables.map((row) => row.read<String>('name')).toSet(), {
      'attachment_blobs',
      'attachment_refs',
    });

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_attachment_%'",
        )
        .get();
    // 3 from the V4→V5 step itself, plus the V5→V6 content-hash index: every
    // step in this migration guards purely on `from`, not `to` (matching the
    // rest of this file), so calling onUpgrade(4, 5) directly — as this test
    // does — also runs the V5→V6 block. A real device only ever migrates to
    // the live schemaVersion in one call, where this is a non-issue.
    expect(indexes, hasLength(4));
    final messages = await db
        .customSelect('SELECT id FROM cached_messages')
        .get();
    expect(messages.single.read<String>('id'), 'm1');
  });

  test(
    'V5 to V6 adds content_hash column and index, keeps existing rows',
    () async {
      await db.customStatement('DROP TABLE attachment_blobs');
      await db.customStatement(
        'CREATE TABLE attachment_blobs (url_key TEXT NOT NULL PRIMARY KEY, '
        'transfer_state INTEGER NOT NULL DEFAULT 0, local_path TEXT)',
      );
      await db.customStatement(
        "INSERT INTO attachment_blobs (url_key, transfer_state) "
        "VALUES ('k1', 2)",
      );

      await db.migration.onUpgrade(db.createMigrator(), 5, 6);

      final columns = await db
          .customSelect('PRAGMA table_info(attachment_blobs)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        contains('content_hash'),
      );

      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_attachment_blobs_content_hash'",
          )
          .get();
      expect(indexes, hasLength(1));

      final row = await db
          .customSelect('SELECT url_key FROM attachment_blobs')
          .getSingle();
      expect(
        row.read<String>('url_key'),
        'k1',
        reason: 'existing rows survive the migration',
      );
    },
  );

  test('a device on V4 jumping straight to V6 does not crash', () async {
    // The realistic path: any install that has not opened the app since
    // before the attachment store shipped goes straight from whatever it had
    // (pre-V5) to the current schema in one `onUpgrade` call, not through V5.
    await db.customStatement('DROP TABLE attachment_refs');
    await db.customStatement('DROP TABLE attachment_blobs');

    await db.migration.onUpgrade(db.createMigrator(), 4, 6);

    final columns = await db
        .customSelect('PRAGMA table_info(attachment_blobs)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('content_hash'),
    );
  });
}
