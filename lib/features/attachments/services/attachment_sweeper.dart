import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../attachment_config.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_dedupe_store.dart';
import '../data/local/attachment_ref_store.dart';
import 'attachment_paths.dart';
import '../../messages/history-transfer/v2/v2_pins.dart';

/// Keeps the on-disk store from growing without bound.
///
/// Five jobs, all best-effort and all silent: free the bytes of a deleted
/// message, drop blobs nothing points at any more, remove abandoned `.part`
/// files, reclaim a duplicate a dedupe commit did not get to delete, and
/// evict least-recently-used files once the budget is exceeded.
///
/// Eviction resets a row to "not downloaded" instead of deleting it, so the
/// user sees a download badge rather than a broken tile — and the exported
/// gallery copy is never touched.
class AttachmentSweeper {
  AttachmentSweeper(this._blobs, this._dedupe, this._refs, this._paths);

  final AttachmentBlobStore _blobs;
  final AttachmentDedupeStore _dedupe;
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

  /// Cold-launch cleanup: only abandoned rows/files, never retained media.
  Future<void> sweepIfDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastSweepKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < sweepInterval.inMilliseconds) return;
      await prefs.setInt(_lastSweepKey, now);
      await _cleanupOrphans();
    } catch (_) {}
  }

  Future<void> sweep() async {
    await _cleanupOrphans();
    await _enforceBudget();
  }

  Future<void> _cleanupOrphans() async {
    for (final urlKey in await _refs.orphanUrlKeys()) {
      await _deleteBlob(urlKey);
    }
    for (final part in await _paths.stalePartFiles(stalePartMaxAge)) {
      try {
        await part.delete();
      } catch (_) {}
    }
    await _reclaimLeakedDuplicates();
  }

  /// A dedupe commit writes the row's canonical path before deleting the
  /// file it deduped away from (see `attachment_job_runner.dart`), so a
  /// process death in that gap leaves that file sitting at its own urlKey's
  /// natural path with nothing pointing at it any more — [row.localPath] has
  /// already moved on to the shared file. That mismatch is exactly what
  /// makes a leaked file safe to identify and remove here.
  Future<void> _reclaimLeakedDuplicates() async {
    for (final row in await _dedupe.all()) {
      final localPath = row.localPath;
      if (localPath == null || localPath.isEmpty) continue;
      final natural = await _paths.fileFor(
        row.urlKey,
        row.fileName,
        row.contentType,
      );
      if (natural.path == localPath) continue;
      try {
        if (await natural.exists()) await natural.delete();
      } catch (_) {}
    }
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
      // A history transfer still has to read this file; evicting it now would
      // turn a photo the phone holds into one the browser is told is gone.
      if (V2Pins.isHeld(row.urlKey)) continue;
      // A content-hash dedupe match means another row still reads this exact
      // file — evicting this row must not pull the bytes out from under it.
      final shared =
          row.localPath != null &&
          row.localPath!.isNotEmpty &&
          await _dedupe.hasOtherReader(row.localPath!, row.urlKey);
      await _blobs.markAbsent(row.urlKey);
      if (!shared) await _deleteFile(row.localPath);
      total -= row.receivedBytes;
    }
  }

  Future<void> _deleteBlob(String urlKey) async {
    final row = await _blobs.read(urlKey);
    final path = row?.localPath ?? '';
    final shared =
        path.isNotEmpty && await _dedupe.hasOtherReader(path, urlKey);
    await _blobs.delete(urlKey);
    if (!shared) await _deleteFile(path);
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

  /// Account reset: every private downloaded byte and every row goes.
  Future<void> clearAll() async {
    await _blobs.clearAll();
    await _refs.clearAll();
    await _paths.deleteAll();
  }
}
