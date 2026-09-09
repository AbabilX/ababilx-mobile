import 'dart:convert';

import '../../attachments/data/local/attachment_blob_store.dart';
import '../data/local/chat_message_store.dart';
import '../data/models/chat_models.dart';
import 'history_transfer_api.dart';
import 'history_transfer_codec.dart';
import 'history_transfer_crypto.dart';
import 'history_transfer_manifest.dart';
import 'history_transfer_snapshot.dart';
import 'history_transfer_snapshot_builder.dart';
import 'history_transfer_uploader.dart';

/// The phone's side of a history transfer, in three phases.
///
/// ```
/// snapshot  seal message chunks onto disk, plan where each file's bytes go
/// upload    send chunk by chunk, resumable, an uploaded chunk never re-sent
/// manifest  seal and commit the index of what was sent, and what was missing
/// ```
///
/// The manifest is committed LAST and freezes the transfer: the server refuses
/// new chunks after it, and refuses completion until every chunk it names has
/// been uploaded and acknowledged. So the order here is not a preference — a
/// manifest sent early would either describe chunks that do not exist yet or
/// close the door on the ones still to come.
class HistoryTransferExporter {
  HistoryTransferExporter({
    required this.api,
    required this.store,
    required this.blobs,
    this.onPhase,
    this.isCancelled,
    this.openSnapshot,
  });

  final HistoryTransferApi api;
  final ChatMessageStore store;
  final AttachmentBlobStore blobs;
  final void Function(HistoryTransferPhase phase, int done, int total)? onPhase;
  final bool Function()? isCancelled;

  /// Where the snapshot lives. Injected only so a test can point it at a
  /// temporary directory; in the app it is always the app-private one.
  final Future<HistoryTransferSnapshot> Function(String transferId)?
  openSnapshot;

  Future<HistoryTransferOutcome> run({
    required String transferId,
    required List<int> transferKey,
    required String deviceId,
    required List<ChatConversation> conversations,
  }) async {
    final snapshot = await (openSnapshot ?? HistoryTransferSnapshot.open)(
      transferId,
    );
    // A plan on disk means an interrupted run. Reuse it: its chunk layout is
    // what the server already has bytes for, and rebuilding would renumber
    // everything under indexes the destination may have read.
    var plan = await snapshot.readPlan();
    if (plan == null || plan.transferId != transferId) {
      onPhase?.call(HistoryTransferPhase.snapshot, 0, 0);
      plan =
          await HistoryTransferSnapshotBuilder(
            store: store,
            blobs: blobs,
            snapshot: snapshot,
            onProgress: (messages, files) =>
                onPhase?.call(HistoryTransferPhase.snapshot, messages, files),
          ).build(
            transferId: transferId,
            transferKey: transferKey,
            deviceId: deviceId,
            conversations: conversations,
          );
    }

    final finished = await HistoryTransferUploader(
      api: api,
      snapshot: snapshot,
      isCancelled: isCancelled,
      onProgress: (done, total) =>
          onPhase?.call(HistoryTransferPhase.upload, done, total),
    ).run(plan);
    if (!finished) {
      return HistoryTransferOutcome(
        completed: false,
        chunks: plan.uploadedThrough + 1,
        files: plan.files.length,
        missingFiles: _missing(plan),
      );
    }

    onPhase?.call(
      HistoryTransferPhase.manifest,
      plan.totalChunks,
      plan.totalChunks,
    );
    final manifest = HistoryTransferManifest(
      createdAtMs: plan.createdAtMs,
      deviceId: plan.deviceId,
      messageChunkCount: plan.messageChunkCount,
      messageCount: plan.messageCount,
      conversationCount: plan.conversationCount,
      attachments: plan.files.map((planned) => planned.file).toList(),
      // Read at the end, not at the start: a message deleted while the
      // snapshot was being written is already inside a sealed chunk, and an
      // explicit deletion outranks anything imported.
      deletionMarkers: store.deletions.records,
    );
    final sealed = await HistoryTransferCrypto.sealManifest(
      transferKey: plan.transferKey,
      plaintext: utf8.encode(jsonEncode(manifest.toJson())),
    );
    await api.commitManifest(
      id: transferId,
      ciphertext: HistoryTransferCodec.b64(sealed),
      chunks: plan.totalChunks,
    );
    await snapshot.discard();
    return HistoryTransferOutcome(
      completed: true,
      chunks: plan.totalChunks,
      files: plan.files.length,
      missingFiles: _missing(plan),
    );
  }

  int _missing(HistoryTransferPlan plan) =>
      plan.files.where((planned) => !planned.file.available).length;
}

enum HistoryTransferPhase { snapshot, upload, manifest }

class HistoryTransferOutcome {
  const HistoryTransferOutcome({
    required this.completed,
    required this.chunks,
    required this.files,
    required this.missingFiles,
  });

  final bool completed;
  final int chunks;
  final int files;

  /// Counted separately and reported separately: a transfer that moved every
  /// message but could not find four photos is not "complete".
  final int missingFiles;
}
