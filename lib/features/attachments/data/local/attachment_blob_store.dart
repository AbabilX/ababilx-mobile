import 'package:drift/drift.dart';

import '../../../messages/data/local/chat_local_db.dart';
import '../models/attachment_handle.dart';
import '../models/media_dimensions.dart';

/// Persistence for the local attachment mirror.
///
/// Every method swallows its errors and returns a safe default: the same rule
/// the rest of the local layer follows — a cache write that fails must never
/// break the conversation on screen. The worst case is a re-download.
class AttachmentBlobStore {
  AttachmentBlobStore(this._db, {this.onForget});

  final ChatLocalDb _db;

  /// Told when a file leaves the disk (null key: all of them), so
  /// `AttachmentHandleMemory` never offers a renderer an evicted path.
  final void Function(String? urlKey, {required bool keepDimensions})? onForget;

  Future<AttachmentBlob?> read(String urlKey) async {
    if (urlKey.isEmpty) return null;
    try {
      return await (_db.select(
        _db.attachmentBlobs,
      )..where((t) => t.urlKey.equals(urlKey))).getSingleOrNull();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, AttachmentBlob>> readAll(Iterable<String> urlKeys) async {
    final keys = urlKeys.where((k) => k.isNotEmpty).toSet().toList();
    if (keys.isEmpty) return const {};
    try {
      final rows = await (_db.select(
        _db.attachmentBlobs,
      )..where((t) => t.urlKey.isIn(keys))).get();
      return {for (final row in rows) row.urlKey: row};
    } catch (_) {
      return const {};
    }
  }

  Future<bool> isReady(String urlKey) async {
    final row = await read(urlKey);
    return row != null &&
        row.transferState == AttachmentTransferState.ready.index &&
        (row.localPath ?? '').isNotEmpty;
  }

  /// Creates the row if this object has never been seen. Existing rows are
  /// left alone — their transfer state is the interesting part.
  Future<void> ensure({
    required String urlKey,
    required String remoteUrl,
    required String fileName,
    required String contentType,
    required int expectedBytes,
  }) async {
    if (urlKey.isEmpty) return;
    try {
      await _db
          .into(_db.attachmentBlobs)
          .insert(
            AttachmentBlobsCompanion.insert(
              urlKey: urlKey,
              remoteUrl: remoteUrl,
              fileName: Value(fileName),
              contentType: Value(contentType),
              expectedBytes: Value(expectedBytes),
              lastAccessMs: Value(DateTime.now().millisecondsSinceEpoch),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } catch (_) {}
  }

  Future<void> setState(
    String urlKey,
    AttachmentTransferState state, {
    int? receivedBytes,
    int? expectedBytes,
    String? lastError,
    int? attempts,
  }) async {
    await _update(
      urlKey,
      AttachmentBlobsCompanion(
        transferState: Value(state.index),
        receivedBytes: receivedBytes == null
            ? const Value.absent()
            : Value(receivedBytes),
        expectedBytes: expectedBytes == null || expectedBytes <= 0
            ? const Value.absent()
            : Value(expectedBytes),
        lastError: Value(lastError ?? ''),
        attempts: attempts == null ? const Value.absent() : Value(attempts),
      ),
    );
  }

  Future<void> markReady(
    String urlKey,
    String localPath,
    int bytes, {
    String contentHash = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _update(
      urlKey,
      AttachmentBlobsCompanion(
        transferState: Value(AttachmentTransferState.ready.index),
        localPath: Value(localPath),
        receivedBytes: Value(bytes),
        expectedBytes: Value(bytes),
        downloadedAtMs: Value(now),
        lastAccessMs: Value(now),
        lastError: const Value(''),
        attempts: const Value(0),
        contentHash: contentHash.isEmpty
            ? const Value.absent()
            : Value(contentHash),
      ),
    );
  }

  /// Measured once per object; a failed write is just measured again later.
  Future<void> setDimensions(String urlKey, MediaDimensions size) => _update(
    urlKey,
    AttachmentBlobsCompanion(
      mediaWidth: Value(size.width),
      mediaHeight: Value(size.height),
    ),
  );

  /// The file is gone (evicted, wiped by the OS, deleted by the user). Keep
  /// the row, size included, so the tile shows "download", not a broken tile.
  Future<void> markAbsent(String urlKey) async {
    onForget?.call(urlKey, keepDimensions: true);
    await _update(
      urlKey,
      AttachmentBlobsCompanion(
        transferState: Value(AttachmentTransferState.absent.index),
        localPath: const Value(null),
        receivedBytes: const Value(0),
        downloadedAtMs: const Value(null),
      ),
    );
  }

  /// Bumps the LRU timestamp. Callers throttle this — a scrolling timeline
  /// resolves the same attachment many times a second.
  Future<void> touch(String urlKey) => _update(
    urlKey,
    AttachmentBlobsCompanion(
      lastAccessMs: Value(DateTime.now().millisecondsSinceEpoch),
    ),
  );

  /// Ready blobs, least recently used first — the eviction order.
  Future<List<AttachmentBlob>> readyByLastAccess() async {
    try {
      return await (_db.select(_db.attachmentBlobs)
            ..where(
              (t) =>
                  t.transferState.equals(AttachmentTransferState.ready.index),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.lastAccessMs)]))
          .get();
    } catch (_) {
      return const [];
    }
  }

  Future<void> delete(String urlKey) async {
    if (urlKey.isEmpty) return;
    onForget?.call(urlKey, keepDimensions: false);
    try {
      await (_db.delete(
        _db.attachmentBlobs,
      )..where((t) => t.urlKey.equals(urlKey))).go();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    onForget?.call(null, keepDimensions: false);
    await _db.delete(_db.attachmentBlobs).go();
  }

  Future<void> _update(String urlKey, AttachmentBlobsCompanion patch) async {
    if (urlKey.isEmpty) return;
    try {
      await (_db.update(
        _db.attachmentBlobs,
      )..where((t) => t.urlKey.equals(urlKey))).write(patch);
    } catch (_) {}
  }
}
