import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'chat_local_tables.dart';

part 'chat_local_db.g.dart';

@DriftDatabase(tables: [CachedSidebars])
class ChatLocalDb extends _$ChatLocalDb {
  ChatLocalDb() : super(_openConnection());

  ChatLocalDb.forTesting(super.e);


  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ababilx_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
