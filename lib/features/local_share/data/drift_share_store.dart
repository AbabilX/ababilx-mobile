import 'package:drift/drift.dart';

import '../engine/store/share_records.dart';
import '../engine/store/share_store.dart';
import 'local_share_db.dart';
import 'share_row_mappers.dart';

export 'share_row_mappers.dart';

/// The engine's [ShareStore] over [LocalShareDb].
class DriftShareStore implements ShareStore {
  DriftShareStore(this.db);

  final LocalShareDb db;

  @override
  Future<ShareDeviceRecord?> device(String deviceId) async {
    final row = await (db.select(
      db.lsDevices,
    )..where((d) => d.deviceId.equals(deviceId))).getSingleOrNull();
    return row == null ? null : shareDeviceOf(row);
  }

  @override
  Future<void> saveDevice(ShareDeviceRecord device) => db
      .into(db.lsDevices)
      .insertOnConflictUpdate(
        LsDevicesCompanion.insert(
          deviceId: device.deviceId,
          name: device.name,
          deviceType: device.deviceType,
          userId: Value(device.userId),
          pairToken: Value(device.pairToken),
          blocked: Value(device.blocked),
          lastIp: Value(device.lastIp),
          lastPort: Value(device.lastPort),
          lastSeenMs: Value(device.lastSeenMs),
        ),
      );

  @override
  Future<ShareMessageRecord?> message(String messageId) async {
    final row = await (db.select(
      db.lsMessages,
    )..where((m) => m.id.equals(messageId))).getSingleOrNull();
    return row == null ? null : shareMessageOf(row);
  }

  @override
  Future<List<ShareFileRecord>> filesOf(String messageId) async {
    final rows =
        await (db.select(db.lsFiles)
              ..where((f) => f.messageId.equals(messageId))
              ..orderBy([(f) => OrderingTerm.asc(f.position)]))
            .get();
    return rows.map(shareFileOf).toList();
  }

  @override
  Future<ShareFileRecord?> file(String messageId, String fileId) async {
    final row =
        await (db.select(db.lsFiles)..where(
              (f) => f.messageId.equals(messageId) & f.id.equals(fileId),
            ))
            .getSingleOrNull();
    return row == null ? null : shareFileOf(row);
  }

  @override
  Future<bool> insertMessage(
    ShareMessageRecord message,
    List<ShareFileRecord> files,
  ) {
    return db.transaction(() async {
      final inserted = await db
          .into(db.lsMessages)
          .insert(
            LsMessagesCompanion.insert(
              id: message.id,
              deviceId: message.deviceId,
              fromMe: message.fromMe,
              kind: message.kind.name,
              body: Value(message.text),
              folderName: Value(message.folderName),
              sentAtMs: message.sentAt,
              orderMs: DateTime.now().millisecondsSinceEpoch,
              status: message.status.name,
              unread: Value(message.unread),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (inserted == 0) return false;
      await db.batch((batch) {
        batch.insertAll(db.lsFiles, [
          for (var i = 0; i < files.length; i++)
            LsFilesCompanion.insert(
              messageId: message.id,
              id: files[i].id,
              position: i,
              name: files[i].name,
              size: files[i].size,
              mime: files[i].mime,
              localPath: files[i].localPath,
              relPath: Value(files[i].relPath),
              width: Value(files[i].width),
              height: Value(files[i].height),
              durationMs: Value(files[i].durationMs),
              bytesDone: Value(files[i].bytesDone),
              status: files[i].status.name,
              owned: Value(files[i].owned),
            ),
        ]);
      });
      return true;
    });
  }

  @override
  Future<void> setMessageStatus(String messageId, ShareMessageStatus status) =>
      (db.update(db.lsMessages)..where((m) => m.id.equals(messageId))).write(
        LsMessagesCompanion(status: Value(status.name)),
      );

  @override
  Future<void> setFileState(
    String messageId,
    String fileId, {
    required int bytesDone,
    required ShareFileStatus status,
  }) =>
      (db.update(db.lsFiles)
            ..where((f) => f.messageId.equals(messageId) & f.id.equals(fileId)))
          .write(
            LsFilesCompanion(
              bytesDone: Value(bytesDone),
              status: Value(status.name),
            ),
          );

  @override
  Future<List<ShareFileRecord>> deleteMessage(String messageId) {
    return db.transaction(() async {
      final files = await filesOf(messageId);
      await (db.delete(
        db.lsFiles,
      )..where((f) => f.messageId.equals(messageId))).go();
      await (db.delete(
        db.lsMessages,
      )..where((m) => m.id.equals(messageId))).go();
      return files;
    });
  }
}
