import 'dart:math';

import '../../../attachments/data/local/attachment_blob_store.dart';
import '../../data/local/chat_message_store.dart';
import '../../data/models/chat_models.dart';
import 'v2_api.dart';
import 'v2_batch_uploader.dart';
import 'v2_conversations.dart';
import 'v2_crypto.dart';
import 'v2_descriptor.dart';
import 'v2_inventory.dart';
import 'v2_media_plan.dart';
import 'v2_media_source.dart';
import 'v2_message_batches.dart';
import 'v2_pins.dart';
import 'v2_plan.dart';
import 'v2_store.dart';

enum V2Phase { planning, uploading, waiting, done }

typedef V2Progress =
    void Function(V2Phase phase, int batch, int batches, int done, int total);

/// The phone's side of a v2 transfer, start to finish or from wherever the
/// last run stopped.
///
/// ```
/// plan     seal message batches to disk, lay media out across batches
/// batch    create -> chunks -> pages -> finalize -> (final: seal) -> wait commit
/// ```
///
/// Messages go first so the browser can show them while video is still on
/// its way. The next batch starts only after the browser has committed the
/// previous one; that is what bounds what the relay ever holds.
class HistoryTransferV2Exporter {
  HistoryTransferV2Exporter({
    required this.api,
    required this.messages,
    required this.blobs,
    required this.conversations,
    this.onProgress,
    this.isCancelled,
    this.openStore = V2Store.open,
    this.pollEvery = const Duration(seconds: 3),
    this.destinationInventoryWait = const Duration(seconds: 60),
  });

  final HistoryTransferV2Api api;
  final ChatMessageStore messages;
  final AttachmentBlobStore blobs;
  final List<ChatConversation> conversations;
  final V2Progress? onProgress;
  final bool Function()? isCancelled;
  final Future<V2Store> Function(String transferId) openStore;
  final Duration pollEvery;

  /// How long planning waits for the browser's list of files it already has.
  final Duration destinationInventoryWait;

  bool get _cancelled => isCancelled?.call() ?? false;

  /// `transferKey` is given on the first run and read back from secure
  /// storage on a resume.
  Future<V2Outcome> run({
    required String transferId,
    List<int>? transferKey,
  }) async {
    final store = await openStore(transferId);
    if (transferKey != null) await store.writeKey(transferId, transferKey);
    final key = transferKey ?? await store.readKey(transferId);
    if (key == null) {
      throw StateError('this transfer cannot be resumed on this phone');
    }

    final capabilities = await retrying(api.capabilities);
    final limits = validateHistoryTransferV2Capabilities(capabilities);

    final plan =
        await store.readPlan() ?? await _plan(store, transferId, key, limits);
    if (plan.batches.length > limits.maxBatches ||
        plan.batches.any((batch) => batch.chunkCount > limits.targetChunks)) {
      throw StateError(
        'This history needs more batches than the server allows.',
      );
    }
    V2Pins.hold(
      plan.files.where((f) => f.status == 'available').map((f) => f.urlKey),
    );
    try {
      if (!plan.inventorySent) {
        if (plan.inventoryCiphertext.isEmpty) {
          plan.inventoryCiphertext = await sealInventory(plan, key);
          await store.writePlan(plan);
        }
        await retrying(
          () => api.putInventory(transferId, plan.inventoryCiphertext),
        );
        plan.inventorySent = true;
        await store.writePlan(plan);
      }
      final media = V2MediaSource(plan);
      final uploader = V2BatchUploader(
        api: api,
        store: store,
        plan: plan,
        transferKey: key,
        media: media,
        deletions: () => messages.deletions.records,
        isCancelled: isCancelled,
        onChunk: (b, n) => onProgress?.call(
          V2Phase.uploading,
          b.batch,
          plan.batches.length,
          n,
          b.chunkCount,
        ),
      );
      for (final batch in plan.batches) {
        if (batch.committed) continue;
        onProgress?.call(
          V2Phase.uploading,
          batch.batch,
          plan.batches.length,
          0,
          batch.chunkCount,
        );
        if (!await uploader.run(batch)) {
          return V2Outcome.of(plan, completed: false);
        }
        if (batch.isFinal && !plan.sealSent) {
          if (plan.sealCiphertext.isEmpty) {
            plan.sealCiphertext = await sealJobSeal(
              plan,
              key,
              messages.deletions.records,
            );
            await store.writePlan(plan);
          }
          await retrying(
            () => api.putSeal(transferId, batch.batch, plan.sealCiphertext),
          );
          plan.sealSent = true;
          await store.writePlan(plan);
        }
        onProgress?.call(
          V2Phase.waiting,
          batch.batch,
          plan.batches.length,
          0,
          0,
        );
        if (!await _waitCommitted(transferId, batch.batch)) {
          return V2Outcome.of(plan, completed: false);
        }
        batch.state = 'committed';
        await store.writePlan(plan);
        await store.dropBatch(batch.batch);
      }
      onProgress?.call(V2Phase.done, plan.lastBatch, plan.batches.length, 0, 0);
      await store.discard(transferId);
      return V2Outcome.of(plan, completed: true);
    } finally {
      V2Pins.release();
    }
  }

  Future<V2Plan> _plan(
    V2Store store,
    String transferId,
    List<int> key,
    V2ServerLimits limits,
  ) async {
    onProgress?.call(V2Phase.planning, 0, 0, 0, 0);
    final frames = V2Conversations(conversations);
    final builder = V2MessageBatchBuilder(
      messages: messages,
      store: store,
      transferId: transferId,
      transferKey: key,
      conversations: frames,
      targetChunks: limits.targetChunks,
      onProgress: (n) => onProgress?.call(V2Phase.planning, 0, 0, n, 0),
    );
    final messageBatches = await builder.build();
    final held = await waitForDestinationInventory(
      api,
      transferId,
      key,
      wait: destinationInventoryWait,
      pollEvery: pollEvery,
    );
    final media = await V2MediaPlanner(
      blobs: blobs,
      held: held,
      batchPlainBytes: limits.targetChunks * V2MessageBatchBuilder.chunkBytes,
    ).plan(builder.attachments.values, messageBatches.length);
    final batches = [...messageBatches, ...media.batches]..last.isFinal = true;
    final plan = V2Plan(
      transferId: transferId,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      messageCount: builder.messageCount,
      conversationCount: frames.count,
      batches: batches,
      files: media.files,
    );
    await store.writePlan(plan);
    return plan;
  }

  /// Polls until the browser commits the batch. False when the job closed
  /// (cancelled, expired) or the user cancelled here.
  Future<bool> _waitCommitted(String transferId, int batch) async {
    for (;;) {
      if (_cancelled) return false;
      final job = await retrying(() => api.job(transferId));
      final batches = (job['batches'] as List? ?? []).cast<Map>();
      final row = batches.where((b) => b['batch'] == batch).firstOrNull;
      // Committed first: the browser completes the job the moment the final
      // batch lands, and a completed job is no longer "live".
      if (row?['status'] == 'committed') return true;
      final transfer = job['transfer'];
      if (transfer is Map && transfer['status'] == 'completed') return true;
      if (job['live'] != true) return false;
      await Future<void>.delayed(pollEvery);
    }
  }
}

class V2ServerLimits {
  const V2ServerLimits({required this.targetChunks, required this.maxBatches});

  final int targetChunks;
  final int maxBatches;
}

/// Refuse an incompatible relay before the user approves it. The selected
/// batch target also keeps every planned batch within the handler's chunk,
/// batch and outstanding-byte ceilings.
V2ServerLimits validateHistoryTransferV2Capabilities(
  Map<String, dynamic> value,
) {
  int number(String key) => (value[key] as num?)?.toInt() ?? 0;
  final versions = (value['versions'] as List? ?? const [])
      .whereType<num>()
      .map((v) => v.toInt());
  final chunk = number('plaintext_chunk_bytes');
  final sealedChunk =
      chunk +
      HistoryTransferV2Crypto.nonceBytes +
      HistoryTransferV2Crypto.tagBytes;
  final maxChunk = number('max_chunk_bytes');
  final maxChunks = number('max_chunks_per_batch');
  final maxBatch = number('max_batch_bytes');
  final maxOutstanding = number('max_outstanding_bytes');
  final maxPage = number('max_page_bytes');
  final maxPagePlaintext = number('max_page_plaintext_bytes');
  final pages = number('max_pages_per_batch');
  final batches = number('max_batches');
  final targetChunks = [
    64,
    maxChunks,
    sealedChunk == 0 ? 0 : maxBatch ~/ sealedChunk,
    sealedChunk == 0 ? 0 : maxOutstanding ~/ sealedChunk,
  ].reduce(min);
  if (!versions.contains(2) ||
      chunk != V2MessageBatchBuilder.chunkBytes ||
      maxChunk < sealedChunk ||
      maxPage < 1048571 ||
      maxPagePlaintext < V2Descriptor.slicePlainBytes ||
      pages < V2Descriptor.maxPages ||
      batches <= 0 ||
      targetChunks <= 0) {
    throw StateError(
      'This server does not support this history transfer format.',
    );
  }
  return V2ServerLimits(targetChunks: targetChunks, maxBatches: batches);
}

class V2Outcome {
  const V2Outcome({
    required this.completed,
    required this.messages,
    required this.filesSent,
    required this.filesMissing,
    required this.filesOmitted,
  });

  factory V2Outcome.of(V2Plan plan, {required bool completed}) => V2Outcome(
    completed: completed,
    messages: plan.messageCount,
    filesSent: plan.files.where((f) => f.status == 'available').length,
    filesMissing: plan.files.where((f) => f.status == 'missing').length,
    filesOmitted: plan.files.where((f) => f.status == 'omitted').length,
  );

  final bool completed;
  final int messages;
  final int filesSent;
  final int filesMissing;
  final int filesOmitted;
}
