import 'package:drift/drift.dart';

import '../../../messages/data/local/chat_local_db.dart';
import '../models/attachment_handle.dart';

/// The content-hash side of the local mirror: which rows share one physical
/// file on disk.
///
/// Split out of [AttachmentBlobStore] purely for file size — it queries the
/// same `attachment_blobs` table, just by `content_hash`/`local_path` instead
/// of `url_key`.
class AttachmentDedupeStore {
  AttachmentDedupeStore(this._db);

  final ChatLocalDb _db;

  /// Every row, regardless of state — the sweeper's leaked-duplicate pass
  /// needs even a `downloading`/`failed` row's `urlKey`/`fileName` to compute
  /// where its own file *would* live, independent of what it is deduped to.
  Future<List<AttachmentBlob>> all() async {
    try {
      return await _db.select(_db.attachmentBlobs).get();
    } catch (_) {
      return const [];
    }
  }

  /// An existing ready blob with identical bytes, if this device already
  /// downloaded them under a different [urlKey] — the disk-dedupe lookup a
  /// finished download checks before keeping its own copy.
  Future<AttachmentBlob?> findReadyByContentHash(
    String contentHash, {
    required String excludingUrlKey,
  }) async {
    if (contentHash.isEmpty) return null;
    try {
      return await (_db.select(_db.attachmentBlobs)
            ..where(
              (t) =>
                  t.contentHash.equals(contentHash) &
                  t.transferState.equals(AttachmentTransferState.ready.index) &
                  t.urlKey.equals(excludingUrlKey).not(),
            )
            ..limit(1))
          .getSingleOrNull();
    } catch (_) {
      return null;
    }
  }

  /// Whether some row other than [excludingUrlKey] still has [localPath] as
  /// its file — the refcount a shared (deduped) file is deleted against, so
  /// eviction or a deleted message never pulls the bytes out from under a
  /// row that is still reading them.
  Future<bool> hasOtherReader(String localPath, String excludingUrlKey) async {
    if (localPath.isEmpty) return false;
    try {
      final rows =
          await (_db.select(_db.attachmentBlobs)..where(
                (t) =>
                    t.localPath.equals(localPath) &
                    t.urlKey.equals(excludingUrlKey).not(),
              ))
              .get();
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
