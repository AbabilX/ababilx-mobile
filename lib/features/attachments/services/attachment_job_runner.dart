import 'dart:math';

import 'package:dio/dio.dart';

import '../../messages/data/models/chat_attachment.dart';
import '../attachment_config.dart';
import '../crypto/sealed_download.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_dedupe_store.dart';
import '../data/models/attachment_handle.dart';
import 'attachment_content_dedupe.dart';
import 'attachment_content_hash.dart';
import 'attachment_dimension_reader.dart';
import 'attachment_downloader.dart';
import 'attachment_failure.dart';
import 'attachment_paths.dart';
import 'attachment_policy.dart';

/// Runs exactly one attachment transfer, retries included, and reports every
/// state change through [emit].
///
/// Split out of [AttachmentQueue] so the queue is only about *which* jobs run
/// and this is only about *how* one job behaves.
class AttachmentJobRunner {
  AttachmentJobRunner(
    this._blobs,
    this._dedupe,
    this._paths,
    this._downloader,
    this._emit, {
    this._dimensions,
  });

  final AttachmentBlobStore _blobs;
  final AttachmentDedupeStore _dedupe;
  final AttachmentPaths _paths;
  final AttachmentDownloader _downloader;
  final void Function(AttachmentHandle handle) _emit;
  final AttachmentDimensionReader? _dimensions;
  final _random = Random();

  /// One token covers the whole job, including retry delays.
  Future<AttachmentHandle> run({
    required ChatMessageAttachment attachment,
    required AttachmentHandle initial,
    required bool userInitiated,
    required CancelToken token,
  }) async {
    final urlKey = initial.urlKey;
    final maxAttempts = userInitiated ? maxUserAttempts : maxAutoAttempts;
    var handle = initial;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (token.isCancelled) throw token.cancelError!;
        return await _transfer(attachment, handle, userInitiated, token);
      } catch (error) {
        if (isCancellation(error)) {
          // The `.part` file survives, so resuming later costs nothing already
          // transferred. Park as "not downloaded", not as a failure.
          handle = handle.copyWith(state: AttachmentTransferState.absent);
          await _blobs.setState(urlKey, AttachmentTransferState.absent);
          _emit(handle);
          return handle;
        }
        final failure = classifyDownloadError(error);
        if (!userInitiated && failure.code == oversizeFailure.code) {
          handle = handle.copyWith(
            state: AttachmentTransferState.absent,
            errorMessage: '',
          );
          await _blobs.setState(urlKey, AttachmentTransferState.absent);
          _emit(handle);
          return handle;
        }
        if (failure.permanent || attempt == maxAttempts - 1) {
          return _fail(urlKey, handle, failure, attempt + 1);
        }
        await Future.any([
          Future<void>.delayed(_backoff(attempt)),
          token.whenCancel.then((_) {}),
        ]);
      }
    }
    return handle;
  }

  Future<AttachmentHandle> _transfer(
    ChatMessageAttachment attachment,
    AttachmentHandle handle,
    bool userInitiated,
    CancelToken token,
  ) async {
    final urlKey = handle.urlKey;
    final target = await _paths.fileFor(
      urlKey,
      attachment.fileName,
      attachment.contentType,
    );

    var current = handle.copyWith(state: AttachmentTransferState.downloading);
    _emit(current);
    await _blobs.setState(urlKey, AttachmentTransferState.downloading);

    var lastPersist = DateTime.now();
    final outcome = await fetchAttachment(
      _downloader,
      _paths,
      attachment,
      target: target,
      maxBytes: downloadByteCeiling(userInitiated: userInitiated),
      cancelToken: token,
      onProgress: (received, total) {
        current = current.copyWith(receivedBytes: received, totalBytes: total);
        _emit(current);
        final now = DateTime.now();
        if (now.difference(lastPersist) < progressPersistInterval) return;
        lastPersist = now;
        _blobs
            .setState(
              urlKey,
              AttachmentTransferState.downloading,
              receivedBytes: received,
              expectedBytes: total,
            )
            .ignore();
      },
    );

    final hash = await hashFileContents(outcome.file);
    final resolution = await resolveDedupedStoragePath(
      _dedupe,
      urlKey,
      hash,
      outcome.file,
    );

    // The database write is the commit point — it must land before the
    // redundant file is touched. A crash between them leaves an orphan file
    // the sweeper can find and reclaim; the reverse order could leave this
    // row pointing at bytes that no longer exist.
    await _blobs.markReady(
      urlKey,
      resolution.path,
      outcome.bytes,
      contentHash: hash,
    );
    final redundant = resolution.redundantFile;
    if (redundant != null) {
      try {
        await redundant.delete();
      } catch (_) {}
    }

    var ready = current.copyWith(
      state: AttachmentTransferState.ready,
      localPath: resolution.path,
      receivedBytes: outcome.bytes,
      totalBytes: outcome.bytes,
      errorMessage: '',
    );
    // Sized before anyone is told it is ready, so no tile ever draws this
    // photo at a guessed height first.
    ready = await _dimensions?.complete(ready) ?? ready;
    _emit(ready);
    return ready;
  }

  Future<AttachmentHandle> _fail(
    String urlKey,
    AttachmentHandle handle,
    AttachmentDownloadFailure failure,
    int attempts,
  ) async {
    final state = failure.permanent
        ? AttachmentTransferState.permanentlyFailed
        : AttachmentTransferState.failed;
    await _blobs.setState(
      urlKey,
      state,
      lastError: failure.message,
      attempts: attempts,
    );
    final failed = handle.copyWith(state: state, errorMessage: failure.message);
    _emit(failed);
    return failed;
  }

  Duration _backoff(int attempt) {
    final base = retryBackoff[attempt.clamp(0, retryBackoff.length - 1)];
    return base + Duration(milliseconds: _random.nextInt(retryJitterMs));
  }
}
