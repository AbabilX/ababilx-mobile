import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../messages/data/models/chat_attachment.dart';
import '../attachment_config.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/models/attachment_handle.dart';
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
    this._paths,
    this._downloader,
    this._emit,
    this._onReady,
  );

  final AttachmentBlobStore _blobs;
  final AttachmentPaths _paths;
  final AttachmentDownloader _downloader;
  final void Function(AttachmentHandle handle) _emit;
  final Future<void> Function(AttachmentHandle handle)? _onReady;
  final _random = Random();

  /// [registerToken] hands each attempt's cancel token back to the queue, so a
  /// user tapping ✕ cancels the attempt that is actually running.
  Future<AttachmentHandle> run({
    required ChatMessageAttachment attachment,
    required AttachmentHandle initial,
    required bool userInitiated,
    required void Function(CancelToken token) registerToken,
  }) async {
    final urlKey = initial.urlKey;
    final maxAttempts = userInitiated ? maxUserAttempts : maxAutoAttempts;
    var handle = initial;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final token = CancelToken();
      registerToken(token);
      try {
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
        await Future<void>.delayed(_backoff(attempt));
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
    final outcome = await _downloader.fetch(
      remoteUrl: attachment.fileUrl,
      target: target,
      partFile: _paths.partFor(target),
      expectedBytes: attachment.sizeBytes,
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

    await _blobs.markReady(urlKey, outcome.file.path, outcome.bytes);
    final ready = current.copyWith(
      state: AttachmentTransferState.ready,
      localPath: outcome.file.path,
      receivedBytes: outcome.bytes,
      totalBytes: outcome.bytes,
      errorMessage: '',
    );
    _emit(ready);
    // Publishing a user-visible copy is a courtesy, never a gate on playback.
    unawaited(Future(() => _onReady?.call(ready)).catchError((_) {}));
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
