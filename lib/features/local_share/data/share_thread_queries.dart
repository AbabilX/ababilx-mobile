import 'package:drift/drift.dart';

import '../engine/store/share_records.dart';
import 'drift_share_store.dart';
import 'local_share_db.dart';

/// One row of the thread list.
class ShareThread {
  const ShareThread({
    required this.device,
    required this.unread,
    this.last,
    this.lastFileName,
    this.lastFileCount = 0,
    this.lastOrderMs = 0,
  });

  final ShareDeviceRecord device;
  final int unread;
  final ShareMessageRecord? last;
  final String? lastFileName;
  final int lastFileCount;
  final int lastOrderMs;
}

/// A message with its files, as the timeline draws it.
class ShareBubbleData {
  const ShareBubbleData(this.message, this.files);

  final ShareMessageRecord message;
  final List<ShareFileRecord> files;
}

/// What the screens read. Everything is a watch over the database: the engine
/// writes rows, the UI redraws from them, and nothing is kept in between.
class ShareThreadQueries {
  ShareThreadQueries(this.db);

  final LocalShareDb db;

  Stream<void> get _changes => db
      .tableUpdates(
        TableUpdateQuery.onAllTables([db.lsDevices, db.lsMessages, db.lsFiles]),
      )
      .map((_) {});

  Stream<T> _watch<T>(Future<T> Function() load) async* {
    yield await load();
    await for (final _ in _changes) {
      yield await load();
    }
  }

  /// Devices that are paired or have history, newest activity first.
  Stream<List<ShareThread>> watchThreads() => _watch(() async {
    final devices = await db.select(db.lsDevices).get();
    final threads = <ShareThread>[];
    for (final device in devices) {
      final last =
          await (db.select(db.lsMessages)
                ..where((m) => m.deviceId.equals(device.deviceId))
                ..orderBy([(m) => OrderingTerm.desc(m.orderMs)])
                ..limit(1))
              .getSingleOrNull();
      if (last == null && device.pairToken == null) continue;
      final unread = db.lsMessages.id.count();
      final unreadCount =
          await (db.selectOnly(db.lsMessages)
                ..addColumns([unread])
                ..where(
                  db.lsMessages.deviceId.equals(device.deviceId) &
                      db.lsMessages.unread.equals(true),
                ))
              .map((row) => row.read(unread) ?? 0)
              .getSingle();
      final files = last == null
          ? const <LsFile>[]
          : await (db.select(db.lsFiles)
                  ..where((f) => f.messageId.equals(last.id))
                  ..orderBy([(f) => OrderingTerm.asc(f.position)]))
                .get();
      threads.add(
        ShareThread(
          device: shareDeviceOf(device),
          unread: unreadCount,
          last: last == null ? null : shareMessageOf(last),
          lastFileName: files.isEmpty ? null : files.first.name,
          lastFileCount: files.length,
          lastOrderMs: last?.orderMs ?? device.lastSeenMs,
        ),
      );
    }
    threads.sort((a, b) => b.lastOrderMs.compareTo(a.lastOrderMs));
    return threads;
  });

  Stream<ShareDeviceRecord?> watchDevice(String deviceId) => _watch(() async {
    final row = await (db.select(
      db.lsDevices,
    )..where((d) => d.deviceId.equals(deviceId))).getSingleOrNull();
    return row == null ? null : shareDeviceOf(row);
  });

  /// The newest [limit] bubbles of a thread, newest first.
  Stream<List<ShareBubbleData>> watchThread(String deviceId, int limit) =>
      _watch(() async {
        final messages =
            await (db.select(db.lsMessages)
                  ..where((m) => m.deviceId.equals(deviceId))
                  ..orderBy([(m) => OrderingTerm.desc(m.orderMs)])
                  ..limit(limit))
                .get();
        if (messages.isEmpty) return const <ShareBubbleData>[];
        final files =
            await (db.select(db.lsFiles)
                  ..where((f) => f.messageId.isIn(messages.map((m) => m.id)))
                  ..orderBy([(f) => OrderingTerm.asc(f.position)]))
                .get();
        final byMessage = <String, List<ShareFileRecord>>{};
        for (final file in files) {
          (byMessage[file.messageId] ??= []).add(shareFileOf(file));
        }
        return [
          for (final m in messages)
            ShareBubbleData(shareMessageOf(m), byMessage[m.id] ?? const []),
        ];
      });

  Future<void> markRead(String deviceId) =>
      (db.update(db.lsMessages)
            ..where((m) => m.deviceId.equals(deviceId) & m.unread.equals(true)))
          .write(const LsMessagesCompanion(unread: Value(false)));
}
