import 'package:drift/drift.dart';

import '../engine/protocol/share_peer.dart';
import '../engine/store/share_records.dart';
import 'drift_share_store.dart';
import 'local_share_db.dart';
import 'share_thread_queries.dart';

/// Writes about devices and whole threads.
extension ShareDeviceQueries on ShareThreadQueries {
  /// Keeps a known device's name and address current. A device never met is
  /// not written: being on the same Wi-Fi is not a relationship.
  Future<void> touch(SharePeer peer) =>
      (db.update(
        db.lsDevices,
      )..where((d) => d.deviceId.equals(peer.deviceId))).write(
        LsDevicesCompanion(
          name: Value(peer.name),
          deviceType: Value(peer.deviceType),
          userId: Value(peer.userId),
          lastIp: Value(peer.ip),
          lastPort: Value(peer.port),
          lastSeenMs: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<List<({String ip, int port})>> knownAddresses() async {
    final rows = await (db.select(
      db.lsDevices,
    )..where((d) => d.pairToken.isNotNull() & d.blocked.equals(false))).get();
    return [
      for (final d in rows)
        if (d.lastIp.isNotEmpty) (ip: d.lastIp, port: d.lastPort),
    ];
  }

  Future<void> setPairToken(String deviceId, String? token) =>
      (db.update(db.lsDevices)..where((d) => d.deviceId.equals(deviceId)))
          .write(LsDevicesCompanion(pairToken: Value(token)));

  Future<void> setBlocked(String deviceId, bool blocked) =>
      (db.update(
        db.lsDevices,
      )..where((d) => d.deviceId.equals(deviceId))).write(
        LsDevicesCompanion(
          blocked: Value(blocked),
          pairToken: blocked ? const Value(null) : const Value.absent(),
        ),
      );

  /// Removes a thread's rows (and the device, unless it is blocked); returns
  /// the file rows so the caller can delete what the app owns on disk.
  Future<List<ShareFileRecord>> deleteThread(String deviceId) {
    return db.transaction(() async {
      final ids = db.selectOnly(db.lsMessages)
        ..addColumns([db.lsMessages.id])
        ..where(db.lsMessages.deviceId.equals(deviceId));
      final files = await (db.select(
        db.lsFiles,
      )..where((f) => f.messageId.isInQuery(ids))).get();
      await (db.delete(
        db.lsFiles,
      )..where((f) => f.messageId.isInQuery(ids))).go();
      await (db.delete(
        db.lsMessages,
      )..where((m) => m.deviceId.equals(deviceId))).go();
      await (db.delete(
        db.lsPendingDeletes,
      )..where((p) => p.deviceId.equals(deviceId))).go();
      await (db.delete(db.lsDevices)..where(
            (d) => d.deviceId.equals(deviceId) & d.blocked.equals(false),
          ))
          .go();
      return files.map(shareFileOf).toList();
    });
  }

  Future<void> queueDelete(String id, String deviceId, String targetId) => db
      .into(db.lsPendingDeletes)
      .insertOnConflictUpdate(
        LsPendingDeletesCompanion.insert(
          id: id,
          deviceId: deviceId,
          targetId: targetId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Future<List<LsPendingDelete>> pendingDeletes(String deviceId) => (db.select(
    db.lsPendingDeletes,
  )..where((p) => p.deviceId.equals(deviceId))).get();

  Future<void> clearPendingDelete(String id) =>
      (db.delete(db.lsPendingDeletes)..where((p) => p.id.equals(id))).go();
}
