import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../attachments/data/local/attachment_tables.dart';
import 'chat_local_indexes.dart';
import 'chat_local_migrations.dart';
import 'chat_local_tables.dart';

part 'chat_local_db.g.dart';

@DriftDatabase(
  tables: [
    CachedSidebars,
    CachedMessages,
    PendingOutboxMessages,
    AttachmentBlobs,
    AttachmentRefs,
    CachedConversationKeys,
  ],
)
class ChatLocalDb extends _$ChatLocalDb {
  ChatLocalDb() : super(_openConnection());

  ChatLocalDb.forTesting(super.e);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await ensureChatMessageIndexes(m.database);
    },
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
      // V4 → V5: the local attachment store. Additive only — no backfill and
      // no data read, so every pre-existing attachment simply starts life as
      // "not downloaded" and is fetched on demand.
      if (from < 5) {
        await m.createTable(attachmentBlobs);
        await m.createTable(attachmentRefs);
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachment_blobs_lru '
          'ON attachment_blobs (transfer_state, last_access_ms)',
        );
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachment_refs_url '
          'ON attachment_refs (url_key)',
        );
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachment_refs_message '
          'ON attachment_refs (message_id)',
        );
      }
      // V5 → V6: content-hash dedupe. Additive — every pre-existing row
      // simply has no hash until it is next downloaded.
      if (from < 6) {
        // `createTable` above builds from the *current* Dart schema, which
        // already includes `contentHash` — a device jumping straight from V4
        // (or earlier) gets the column for free out of the `from < 5`
        // branch, so adding it again here would be a duplicate-column error.
        // The index still needs creating either way.
        if (from >= 5) {
          await m.addColumn(attachmentBlobs, attachmentBlobs.contentHash);
        }
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachment_blobs_content_hash '
          'ON attachment_blobs (content_hash)',
        );
      }
      // V6 → V7: the conversation-key envelope cache. Additive, no backfill —
      // there is nothing to carry forward, since the keys only ever existed in
      // memory. Every conversation fills its row the next time it is opened
      // with a connection, and offline reading works from then on.
      if (from < 7) {
        await m.createTable(cachedConversationKeys);
      }
      // V7 → V8: measured media size on the blob row. Additive — a row simply
      // has no size until its file is next resolved. Same guard as V6: a
      // device below V5 already got both columns from `createTable` above.
      if (from < 8 && from >= 5) {
        await m.addColumn(attachmentBlobs, attachmentBlobs.mediaWidth);
        await m.addColumn(attachmentBlobs, attachmentBlobs.mediaHeight);
      }
      // V8 → V9: the message indexes a fresh install never got. Additive —
      // building them reads the table once, and every later read is indexed.
      // V9 → V10: the archive index (backup export order). Same helper, every
      // statement IF NOT EXISTS, so a phone below V9 builds all of them once.
      if (from < 10) {
        await ensureChatMessageIndexes(m.database);
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
