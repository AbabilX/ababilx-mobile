import 'package:drift/drift.dart';

/// A device this account has met on a local network. A row with a
/// [pairToken] is trusted; a [blocked] row stays so the device stays refused.
class LsDevices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get name => text()();
  TextColumn get deviceType => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get pairToken => text().nullable()();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
  TextColumn get lastIp => text().withDefault(const Constant(''))();
  IntColumn get lastPort => integer().withDefault(const Constant(0))();
  IntColumn get lastSeenMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

/// One bubble of a device's thread.
///
/// [orderMs] is THIS device's clock at the moment the row was written and is
/// what the timeline sorts by; [sentAtMs] is the sender's clock and is only
/// shown. Two devices never agree on the time, and sorting by the sender's
/// puts a reply above the message it answers.
@TableIndex(name: 'idx_ls_messages_thread', columns: {#deviceId, #orderMs})
class LsMessages extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  BoolColumn get fromMe => boolean()();
  TextColumn get kind => text()();
  TextColumn get body => text().nullable()();
  TextColumn get folderName => text().nullable()();
  IntColumn get sentAtMs => integer()();
  IntColumn get orderMs => integer()();
  TextColumn get status => text()();
  BoolColumn get unread => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LsFiles extends Table {
  TextColumn get messageId => text()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  IntColumn get size => integer()();
  TextColumn get mime => text()();
  TextColumn get localPath => text()();
  TextColumn get relPath => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get bytesDone => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();

  /// False for an outgoing file still where the user keeps it: deleting the
  /// bubble must not delete their photo.
  BoolColumn get owned => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {messageId, id};
}

/// A delete-for-both the other device has not been told about yet. Sent the
/// next time that device is on the network.
class LsPendingDeletes extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get targetId => text()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
