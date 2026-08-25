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
    expect(indexes, hasLength(3));
    final messages = await db
        .customSelect('SELECT id FROM cached_messages')
        .get();
    expect(messages.single.read<String>('id'), 'm1');
  });
}
