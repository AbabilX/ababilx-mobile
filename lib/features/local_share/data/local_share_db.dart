import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_share_tables.dart';

part 'local_share_db.g.dart';

/// Local Share's own database — one file per signed-in account, beside the
/// files it describes. Kept apart from the chat database on purpose: nothing
/// here ever came from, or goes to, the server.
@DriftDatabase(tables: [LsDevices, LsMessages, LsFiles, LsPendingDeletes])
class LocalShareDb extends _$LocalShareDb {
  LocalShareDb(String userId) : super(_open(userId));

  LocalShareDb.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}

/// `<app support>/local_share/<user id>` — the database and every received
/// file of that account live under it.
Future<Directory> localShareRoot(String userId) async {
  final support = await getApplicationSupportDirectory();
  final safe = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final dir = Directory(p.join(support.path, 'local_share', safe));
  await dir.create(recursive: true);
  return dir;
}

LazyDatabase _open(String userId) {
  return LazyDatabase(() async {
    final root = await localShareRoot(userId);
    return NativeDatabase.createInBackground(
      File(p.join(root.path, 'threads.sqlite')),
    );
  });
}
