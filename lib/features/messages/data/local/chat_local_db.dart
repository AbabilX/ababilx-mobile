import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'chat_local_tables.dart';

part 'chat_local_db.g.dart';

@DriftDatabase(tables: [CachedSidebars, CachedMessageFeeds])
class ChatLocalDb extends _$ChatLocalDb {
  ChatLocalDb() : super(_openConnection());

  ChatLocalDb.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // V1 → V2: create the message-feed cache table.
          if (from < 2) {
            await m.createTable(cachedMessageFeeds);
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
