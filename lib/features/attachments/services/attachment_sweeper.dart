import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../attachment_config.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_ref_store.dart';
import 'attachment_paths.dart';

/// Keeps the on-disk store from growing without bound.
///
/// Four jobs, all best-effort and all silent: free the bytes of a deleted
/// message, drop blobs nothing points at any more, remove abandoned `.part`
/// files, and evict least-recently-used files once the budget is exceeded.
///
/// Eviction resets a row to "not downloaded" instead of deleting it, so the
/// user sees a download badge rather than a broken tile — and the exported
/// gallery copy is never touched.
class AttachmentSweeper {
  AttachmentSweeper(this._blobs, this._refs, this._paths);

  final AttachmentBlobStore _blobs;
  final AttachmentRefStore _refs;
  final AttachmentPaths _paths;

  static const _lastSweepKey = 'attachment_sweep_at_ms';

  /// Called when a message is deleted. Frees only the blobs no other message
  /// (or forward of it) still references.
  Future<void> onMessageDeleted(String messageId) async {
    for (final urlKey in await _refs.removeForMessage(messageId)) {
      await _deleteBlob(urlKey);
    }
  }

  /// Whole-store sweep, throttled to [sweepInterval].
  Future<void> sweepIfDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastSweepKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < sweepInterval.inMilliseconds) return;
      await prefs.setInt(_lastSweepKey, now);
      await sweep();
    } catch (_) {}
  }

  Future<void> sweep() async {
    for (final urlKey in await _refs.orphanUrlKeys()) {
      await _deleteBlob(urlKey);
    }
    for (final part in await _paths.stalePartFiles(stalePartMaxAge)) {
      try {
        await part.delete();
      } catch (_) {}
    }
    await _enforceBudget();
  }

  /// Least-recently-used first, skipping anything recently opened or small
  /// enough that keeping it is free.
  Future<void> _enforceBudget() async {
    final rows = await _blobs.readyByLastAccess();
    var total = rows.fold<int>(0, (sum, row) => sum + row.receivedBytes);
    if (total <= diskBudgetBytes) return;
    final cutoff = DateTime.now()
        .subtract(evictionMinIdle)
        .millisecondsSinceEpoch;
    for (final row in rows) {
      if (total <= diskBudgetBytes) return;
      if (row.lastAccessMs > cutoff) continue;
      if (row.receivedBytes < evictionMinBytes) continue;
      await _deleteFile(row.localPath);
      await _blobs.markAbsent(row.urlKey);
      total -= row.receivedBytes;
    }
  }

  Future<void> _deleteBlob(String urlKey) async {
    final row = await _blobs.read(urlKey);
    await _deleteFile(row?.localPath);
    await _blobs.delete(urlKey);
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      final part = File('$path${AttachmentPaths.partSuffix}');
      if (await part.exists()) await part.delete();
    } catch (_) {}
  }

  /// Sign-out: every downloaded byte and every row goes.
  Future<void> clearAll() async {
    await _blobs.clearAll();
    await _refs.clearAll();
    await _paths.deleteAll();
  }
}
