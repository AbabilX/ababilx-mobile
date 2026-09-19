import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'v2_api.dart';
import 'v2_crypto.dart';
import 'v2_descriptor.dart';
import 'v2_media_source.dart';
import 'v2_plan.dart';
import 'v2_store.dart';

/// Moves one batch from `planned` to `finalized`:
///
/// ```
/// create -> every chunk reserved, PUT, confirmed -> pages -> finalize
/// ```
///
/// Every step is idempotent server-side and recorded in the plan as it lands,
/// so a run killed at any point resumes where it stopped. The server's own
/// "already uploaded" answer, not the local counter, settles a disagreement.
class V2BatchUploader {
  V2BatchUploader({
    required this.api,
    required this.store,
    required this.plan,
    required this.transferKey,
    required this.media,
    required this.deletions,
    this.onChunk,
    this.isCancelled,
  });

  final HistoryTransferV2Api api;
  final V2Store store;
  final V2Plan plan;
  final List<int> transferKey;
  final V2MediaSource media;
  final List<Map<String, dynamic>> Function() deletions;
  final void Function(V2PlannedBatch batch, int uploaded)? onChunk;
  final bool Function()? isCancelled;

  static const _order = [
    'planned',
    'created',
    'uploaded',
    'paged',
    'finalized',
    'committed',
  ];
  bool _before(V2PlannedBatch b, String state) =>
      _order.indexOf(b.state) < _order.indexOf(state);

  Future<bool> run(V2PlannedBatch batch) async {
    final id = plan.transferId;
    if (_before(batch, 'created')) {
      await retrying(
        () => api.createBatch(id, batch.batch, batch.kind, batch.isFinal),
      );
      await _advance(batch, 'created');
    }
    if (_before(batch, 'uploaded')) {
      for (var i = batch.uploadedThrough + 1; i < batch.chunkCount; i++) {
        if (isCancelled?.call() ?? false) return false;
        await _sendChunk(batch, i);
        batch.uploadedThrough = i;
        await store.writePlan(plan);
        onChunk?.call(batch, i + 1);
      }
      await _advance(batch, 'uploaded');
    }
    if (_before(batch, 'paged')) {
      var pages = await store.readPages(batch.batch);
      if (pages == null) {
        final descriptor = await V2Descriptor.build(
          plan: plan,
          batch: batch,
          media: media,
          deletions: deletions(),
        );
        if (media.omittedChanged) {
          media.omittedChanged = false;
          await store.writePlan(plan);
        }
        pages = await V2Descriptor.seal(
          key: transferKey,
          transferId: id,
          batch: batch.batch,
          descriptor: descriptor,
        );
        // Sealed pages are immutable server-side: the same bytes must be sent
        // on every retry, so they are kept before the first one leaves.
        await store.writePages(batch.batch, pages);
      }
      for (var p = 0; p < pages.length; p++) {
        await retrying(() => api.putPage(id, batch.batch, p, pages![p]));
      }
      batch.pageCount = pages.length;
      await _advance(batch, 'paged');
    }
    if (_before(batch, 'finalized')) {
      await retrying(
        () => api.finalize(id, batch.batch, batch.chunkCount, batch.pageCount),
      );
      await _advance(batch, 'finalized');
    }
    return true;
  }

  Future<void> _advance(V2PlannedBatch batch, String state) async {
    batch.state = state;
    await store.writePlan(plan);
  }

  Future<void> _sendChunk(V2PlannedBatch batch, int index) async {
    final id = plan.transferId;
    // Reserve first, with the size alone: on a resume most chunks answer
    // "already uploaded", and reading and sealing 4 MiB to learn that is waste.
    final size = await _sealedSize(batch, index);
    var refusedPuts = 0;
    for (;;) {
      try {
        final slot = await retrying(
          () => api.reserve(id, batch.batch, index, size ?? 1),
        );
        if (slot.uploaded) return;
        final sealed = size == null ? null : await _sealed(batch, index);
        if (sealed == null) {
          throw StateError(
            'the sealed copy of batch ${batch.batch} chunk $index is gone',
          );
        }
        try {
          await retrying(() => api.put(slot.url, sealed));
        } on DioException catch (error) {
          // A signed URL that expired while the phone slept is refused by the
          // store; a fresh reservation signs a new one for the same object.
          final status = error.response?.statusCode ?? 0;
          if ((status == 403 || status == 400) && ++refusedPuts < 3) continue;
          rethrow;
        }
        await retrying(
          () => api.confirm(
            id,
            batch.batch,
            index,
            sha256.convert(sealed).toString(),
          ),
        );
        return;
      } on HistoryTransferRelayBusy catch (busy) {
        // The job already holds its allowance in the relay; committed batches
        // are deleted on a timer. Waiting is the whole answer.
        await Future<void>.delayed(busy.retryAfter);
      }
    }
  }

  /// Sealed length without producing the bytes: a message chunk's file size,
  /// or a media piece's plaintext length plus nonce and tag. Null when a
  /// message chunk's sealed copy is gone from disk.
  Future<int?> _sealedSize(V2PlannedBatch batch, int index) async {
    if (batch.kind == 'messages') {
      final file = store.chunkFile(batch.batch, index);
      return await file.exists() ? file.length() : null;
    }
    final start = index * V2MediaSource.chunkBytes;
    final left = batch.streamBytes - start;
    final plain = left < V2MediaSource.chunkBytes
        ? left
        : V2MediaSource.chunkBytes;
    return plain +
        HistoryTransferV2Crypto.nonceBytes +
        HistoryTransferV2Crypto.tagBytes;
  }

  Future<Uint8List?> _sealed(V2PlannedBatch batch, int index) async {
    if (batch.kind == 'messages') {
      final file = store.chunkFile(batch.batch, index);
      return await file.exists() ? file.readAsBytes() : null;
    }
    final plain = await media.plaintext(batch, index);
    if (media.omittedChanged) {
      media.omittedChanged = false;
      await store.writePlan(plan);
    }
    return HistoryTransferV2Crypto.seal(
      transferKey,
      HistoryTransferV2Crypto.chunkAad(
        plan.transferId,
        batch.batch,
        'media',
        index,
      ),
      plain,
    );
  }
}

final _jitter = Random();

/// Bounded exponential backoff with jitter for transport failures and 5xx.
/// A 4xx is an answer, not a hiccup, and goes straight back to the caller.
Future<T> retrying<T>(Future<T> Function() call, {int attempts = 5}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } on DioException catch (error) {
      final status = error.response?.statusCode ?? 0;
      final transient = status == 0 || status >= 500 || status == 429;
      if (!transient || attempt >= attempts) rethrow;
      final base = 500 * (1 << (attempt - 1));
      await Future<void>.delayed(
        Duration(milliseconds: base + _jitter.nextInt(base)),
      );
    }
  }
}
