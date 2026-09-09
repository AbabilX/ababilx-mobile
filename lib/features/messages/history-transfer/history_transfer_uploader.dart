import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'history_transfer_api.dart';
import 'history_transfer_crypto.dart';
import 'history_transfer_snapshot.dart';
import 'history_transfer_snapshot_builder.dart';

/// Sends the snapshot, one chunk at a time, and can be run again after a
/// crash, a lost network or a phone that went to sleep.
///
/// Resume is decided by the SERVER, not by the local counter: `uploaded_through`
/// says where to start looking, and the reservation's own "already uploaded"
/// answer settles anything the two disagree about. An uploaded chunk is frozen
/// server-side, so a re-send would be refused — skipping is the correct move,
/// not a shortcut.
class HistoryTransferUploader {
  HistoryTransferUploader({
    required this.api,
    required this.snapshot,
    this.onProgress,
    this.isCancelled,
  });

  final HistoryTransferApi api;
  final HistoryTransferSnapshot snapshot;
  final void Function(int uploadedChunks, int totalChunks)? onProgress;

  /// Checked between chunks. Cancelling mid-upload leaves the snapshot in
  /// place; the transfer's own cancel endpoint is what ends it for both sides.
  final bool Function()? isCancelled;

  Future<bool> run(HistoryTransferPlan plan) async {
    final total = plan.totalChunks;
    for (var index = plan.uploadedThrough + 1; index < total; index++) {
      if (isCancelled?.call() ?? false) return false;
      final body = await _chunkBytes(plan, index);
      if (body == null) {
        // A file that vanished between the plan and the upload. The manifest
        // still names it, and the destination will show it as unavailable —
        // the same outcome as never having held it.
        plan.uploadedThrough = index;
        continue;
      }
      final slot = await api.reserveChunk(
        id: plan.transferId,
        index: index,
        kind: index < plan.messageChunkCount ? 'messages' : 'media',
        sizeBytes: body.length,
      );
      if (!slot.alreadyUploaded) {
        await api.putChunk(slot.uploadUrl, body);
        await api.confirmChunk(
          id: plan.transferId,
          index: index,
          // sha256 of the SEALED bytes. The server cannot check it — it holds
          // no key — so this travels for the destination to compare against
          // what it downloaded, one hop earlier than the manifest's hash of
          // the plaintext.
          checksum: sha256.convert(body).toString(),
        );
      }
      plan.uploadedThrough = index;
      await snapshot.writePlan(plan);
      onProgress?.call(index + 1, total);
    }
    return true;
  }

  /// The bytes for one index: a sealed message chunk read off disk, or a slice
  /// of an attachment sealed now.
  ///
  /// Media is sealed at upload time rather than staged: the attachment files
  /// already are the snapshot, and copying a phone's whole media library into
  /// a second directory to send it once is the one thing a device short on
  /// storage cannot afford.
  Future<Uint8List?> _chunkBytes(HistoryTransferPlan plan, int index) async {
    if (index < plan.messageChunkCount) {
      final file = snapshot.messageChunk(index);
      if (!await file.exists()) return null;
      return file.readAsBytes();
    }
    for (final planned in plan.files) {
      final first = planned.file.firstChunk;
      if (!planned.file.available || index < first) continue;
      if (index >= first + planned.chunkCount) continue;
      final offset =
          (index - first) * HistoryTransferSnapshotBuilder.chunkBytes;
      final slice = await _readSlice(planned.localPath, offset);
      if (slice == null) return null;
      return HistoryTransferCrypto.sealChunk(
        transferKey: plan.transferKey,
        index: index,
        plaintext: slice,
      );
    }
    return null;
  }

  Future<Uint8List?> _readSlice(String path, int offset) async {
    RandomAccessFile? handle;
    try {
      handle = await File(path).open();
      await handle.setPosition(offset);
      return await handle.read(HistoryTransferSnapshotBuilder.chunkBytes);
    } catch (_) {
      return null;
    } finally {
      await handle?.close();
    }
  }
}
