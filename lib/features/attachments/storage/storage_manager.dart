import 'dart:io';

import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_dedupe_store.dart';
import '../services/attachment_paths.dart';
import 'storage_usage_query.dart';

/// Freeing space the user asked to free.
///
/// Deliberately the same shape as the LRU eviction in [AttachmentSweeper]:
/// the row is marked **absent**, not deleted. The message keeps its
/// attachment and shows a download badge, so clearing storage never turns a
/// conversation into a wall of broken tiles — and a file cleared by mistake is
/// one tap from coming back.
///
/// A blob whose file is shared by a content-hash duplicate keeps its bytes:
/// another row is still reading them, and the caller only asked about this one.
class StorageManager {
  StorageManager(this._blobs, this._dedupe, this._query);

  final AttachmentBlobStore _blobs;
  final AttachmentDedupeStore _dedupe;
  final StorageUsageQuery _query;

  /// Returns the bytes actually reclaimed — which is less than the sum of the
  /// rows when two of them shared one file.
  Future<int> release(Iterable<String> urlKeys) async {
    var freed = 0;
    for (final urlKey in urlKeys.toSet()) {
      final row = await _blobs.read(urlKey);
      if (row == null) continue;
      final path = row.localPath ?? '';
      final shared =
          path.isNotEmpty && await _dedupe.hasOtherReader(path, urlKey);
      await _blobs.markAbsent(urlKey);
      if (!shared && await _deleteFile(path)) freed += row.receivedBytes;
    }
    return freed;
  }

  Future<int> releaseConversation(String conversationId) async {
    if (conversationId.isEmpty) return 0;
    final items = await _query.items(
      limit: 1 << 30,
      conversationId: conversationId,
    );
    return release(items.map((item) => item.urlKey));
  }

  /// Everything belonging to a conversation the user deleted.
  ///
  /// Unlike [releaseConversation], which frees space and leaves a download
  /// badge behind, this drops the blob row as well: there is no message left
  /// to draw a badge on, and a row holding the attachment's URL is a record of
  /// a chat that is supposed to be gone.
  ///
  /// A file shared with a surviving row through content-hash dedupe keeps its
  /// bytes; only this conversation's claim on it goes.
  Future<int> purgeConversation(String conversationId) async {
    if (conversationId.isEmpty) return 0;
    final items = await _query.items(
      limit: 1 << 30,
      conversationId: conversationId,
    );
    return purgeUrlKeys(items.map((item) => item.urlKey));
  }

  /// Drops these blobs outright — row and file — the way a deleted
  /// conversation's are. Also what an expired timed photo takes (privacy
  /// mode): no badge, no way to download it again, because the object is gone
  /// from the server too.
  Future<int> purgeUrlKeys(Iterable<String> urlKeys) async {
    var freed = 0;
    for (final urlKey in urlKeys.toSet()) {
      final row = await _blobs.read(urlKey);
      if (row == null) {
        await _blobs.delete(urlKey);
        continue;
      }
      final path = row.localPath ?? '';
      final shared =
          path.isNotEmpty && await _dedupe.hasOtherReader(path, urlKey);
      await _blobs.delete(urlKey);
      if (!shared && await _deleteFile(path)) freed += row.receivedBytes;
    }
    return freed;
  }

  /// Everything downloaded before [cutoff].
  ///
  /// The one action that keeps the store small without anybody picking files
  /// by hand: old media is what accumulates, and a chat that is still being
  /// read keeps re-downloading what it needs.
  ///
  /// A row with no `downloadedAtMs` — written before the column was — is left
  /// alone rather than treated as infinitely old, so "older than a year" can
  /// never quietly mean "everything".
  Future<int> releaseOlderThan(DateTime cutoff) async {
    final ms = cutoff.millisecondsSinceEpoch;
    final rows = await _blobs.readyByLastAccess();
    return release([
      for (final row in rows)
        if ((row.downloadedAtMs ?? 0) > 0 && row.downloadedAtMs! < ms)
          row.urlKey,
    ]);
  }

  /// Everything downloaded, in one action.
  ///
  /// Row by row rather than [AttachmentPaths.deleteAll] so the rows are left
  /// consistent with the disk: wiping the directory under live rows would
  /// leave every tile pointing at a file that is gone, with no badge offering
  /// to fetch it again.
  Future<int> releaseAll() async {
    final rows = await _blobs.readyByLastAccess();
    return release(rows.map((row) => row.urlKey));
  }

  Future<bool> _deleteFile(String path) async {
    if (path.isEmpty) return false;
    try {
      final file = File(path);
      final existed = await file.exists();
      if (existed) await file.delete();
      final part = File('$path${AttachmentPaths.partSuffix}');
      if (await part.exists()) await part.delete();
      return existed;
    } catch (_) {
      return false;
    }
  }
}
