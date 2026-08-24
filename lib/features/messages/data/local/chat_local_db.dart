import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'chat_local_migrations.dart';
import 'chat_local_tables.dart';

part 'chat_local_db.g.dart';

@DriftDatabase(tables: [CachedSidebars, CachedMessages, PendingOutboxMessages])
class ChatLocalDb extends _$ChatLocalDb {
  ChatLocalDb() : super(_openConnection());

  ChatLocalDb.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // V2 → V3: create the durable send outbox.
      if (from < 3) {
        await m.createTable(pendingOutboxMessages);
      }
      // V3 → V4: per-message rows replace the per-conversation JSON blob.
      // The old table is read once for its contents, then dropped.
      if (from < 4) {
        await m.createTable(cachedMessages);
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_cached_messages_conv_time '
          'ON cached_messages (conversation_id, created_at_ms)',
        );
        await backfillMessageRowsFromFeedBlobs(this);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ababilx_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
