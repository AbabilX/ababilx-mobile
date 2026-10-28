import 'dart:async';

import 'package:dio/dio.dart';

import '../../messages/data/models/chat_attachment.dart';
import '../attachment_config.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_dedupe_store.dart';
import '../data/models/attachment_handle.dart';
import '../data/models/attachment_url_key.dart';
import 'attachment_dimension_reader.dart';
import 'attachment_downloader.dart';
import 'attachment_job_runner.dart';
import 'attachment_paths.dart';
import 'attachment_semaphore.dart';

/// Decides which transfers are running.
///
/// Deliberately *not* owned by a widget or an autoDispose provider: scrolling
/// an attachment off screen must not cancel its download. The only things that
/// stop a transfer are the user tapping ✕ and the app dying.
///
/// One entry per `urlKey` in [_inFlight] is both the "one job per attachment"
/// rule and the forwarded-message dedupe — two bubbles pointing at the same R2
/// object share a single request and settle on the same handle.
class AttachmentQueue {
  AttachmentQueue(
    this._blobs,
    AttachmentDedupeStore dedupe,
    AttachmentPaths paths,
    AttachmentDownloader downloader, {
    AttachmentSemaphore? semaphore,
    AttachmentDimensionReader? dimensions,
  }) : _gate = semaphore ?? AttachmentSemaphore(maxConcurrentDownloads) {
    _runner = AttachmentJobRunner(
      _blobs,
      dedupe,
      paths,
      downloader,
      _emit,
      dimensions: dimensions,
    );
  }

  final AttachmentBlobStore _blobs;
  final AttachmentSemaphore _gate;
  late final AttachmentJobRunner _runner;

  final _events = StreamController<AttachmentHandle>.broadcast();
  final Map<String, Future<AttachmentHandle>> _inFlight = {};
  final Map<String, CancelToken> _tokens = {};
  bool _stopping = false;

  Stream<AttachmentHandle> get events => _events.stream;

  bool isRunning(String urlKey) => _inFlight.containsKey(urlKey);

  Future<AttachmentHandle> enqueue(
    ChatMessageAttachment attachment, {
    bool userInitiated = false,
  }) {
    final urlKey = attachmentUrlKey(attachment.fileUrl);
    if (_stopping) return Future.value(_absent(attachment, urlKey));
    if (attachment.locked || urlKey.isEmpty) {
      return Future.value(
        AttachmentHandle.locked(fileName: attachment.fileName),
      );
    }
    // Encrypted (server 0168), and its key did not open on this phone: the
    // vault is locked, or the key version is one this account does not hold.
    // There is nothing readable to fetch, so it fails at once — no request,
    // no retries, and nothing written, so the same tap works once the key
    // is there.
    if (attachment.needsKey) {
      final unreadable = AttachmentHandle(
        urlKey: urlKey,
        remoteUrl: attachment.fileUrl,
        state: AttachmentTransferState.failed,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
        errorMessage: 'This file cannot be opened on this phone yet',
      );
      _emit(unreadable);
      return Future.value(unreadable);
    }
    final running = _inFlight[urlKey];
    if (running != null) return running;
    final token = CancelToken();
    _tokens[urlKey] = token;
    final job = _start(urlKey, attachment, userInitiated, token);
    _inFlight[urlKey] = job;
    return job;
  }

  void cancel(String urlKey) {
    _tokens[urlKey]?.cancel('cancelled by user');
  }

  /// Terminal session barrier. The owner replaces this queue before new work.
  Future<void> cancelAll() async {
    _stopping = true;
    for (final token in _tokens.values.toList()) {
      token.cancel('session ended');
    }
    await Future.wait(_inFlight.values.toList());
  }

  Future<AttachmentHandle> _start(
    String urlKey,
    ChatMessageAttachment attachment,
    bool userInitiated,
    CancelToken token,
  ) async {
    final queued = AttachmentHandle(
      urlKey: urlKey,
      remoteUrl: attachment.fileUrl,
      state: AttachmentTransferState.queued,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      totalBytes: attachment.sizeBytes,
    );
    var acquired = false;
    try {
      await _blobs.ensure(
        urlKey: urlKey,
        remoteUrl: attachment.fileUrl,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
        expectedBytes: attachment.sizeBytes,
      );
      _emit(queued);
      await _blobs.setState(urlKey, AttachmentTransferState.queued);

      if (!token.isCancelled) {
        acquired = await _gate.acquire(
          userInitiated: userInitiated,
          cancelled: token.whenCancel.then((_) {}),
        );
      }
      if (!acquired || token.isCancelled) {
        final absent = _absent(attachment, urlKey);
        await _blobs.setState(urlKey, AttachmentTransferState.absent);
        _emit(absent);
        return absent;
      }
      return await _runner.run(
        attachment: attachment,
        initial: queued,
        userInitiated: userInitiated,
        token: token,
      );
    } finally {
      if (acquired) _gate.release();
      _inFlight.remove(urlKey);
      _tokens.remove(urlKey);
    }
  }

  AttachmentHandle _absent(ChatMessageAttachment attachment, String urlKey) =>
      AttachmentHandle(
        urlKey: urlKey,
        remoteUrl: attachment.fileUrl,
        state: AttachmentTransferState.absent,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
      );

  /// Publish a handle nobody downloaded — the sender adopting the file it
  /// just uploaded. Same channel a finished download uses, so a gate already
  /// on screen swaps in place instead of waiting for a re-resolve.
  void announce(AttachmentHandle handle) => _emit(handle);

  void _emit(AttachmentHandle handle) {
    if (!_events.isClosed) _events.add(handle);
  }

  void dispose() {
    _stopping = true;
    for (final token in _tokens.values) {
      token.cancel('queue disposed');
    }
    _tokens.clear();
    _gate.drain();
    _events.close();
  }
}
