import 'dart:async';
import 'dart:io';

import '../../messages/data/models/chat_attachment.dart';
import '../attachment_config.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/models/attachment_handle.dart';
import '../data/models/attachment_url_key.dart';
import 'attachment_queue.dart';

/// The one class a renderer talks to.
///
/// Everything on screen asks "where are the bytes for this attachment" and
/// gets an [AttachmentHandle] — a local file or a reason there isn't one yet.
/// No widget ever sees `fileUrl` again, which is what makes the remote source
/// swappable (and, later, encrypted) without touching the UI.
class AttachmentAuthority {
  AttachmentAuthority(this._blobs, this._queue);

  final AttachmentBlobStore _blobs;
  final AttachmentQueue _queue;
  final Map<String, int> _lastTouchMs = {};

  /// Reads the current state. Database and a `stat` — never the network, so
  /// this is safe to call while building a widget.
  Future<AttachmentHandle> resolve(ChatMessageAttachment attachment) async {
    // Retention-locked: the server sends no URL at all. Never touch the DB and
    // never issue a request for one.
    if (attachment.locked || attachment.fileUrl.isEmpty) {
      return AttachmentHandle.locked(fileName: attachment.fileName);
    }

    final urlKey = attachmentUrlKey(attachment.fileUrl);
    final base = AttachmentHandle(
      urlKey: urlKey,
      remoteUrl: attachment.fileUrl,
      state: AttachmentTransferState.absent,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      totalBytes: attachment.sizeBytes,
    );

    final row = await _blobs.read(urlKey);
    // Never seen — every message that predates this feature lands here, and is
    // simply fetched on demand.
    if (row == null) return base;

    final state = _stateOf(row.transferState);
    final path = row.localPath ?? '';

    if (state == AttachmentTransferState.ready) {
      // The file can vanish under us: an OS cleaner, a restore onto a new
      // device, or our own eviction. Verify before promising a renderer a path.
      if (path.isEmpty || !File(path).existsSync()) {
        await _blobs.markAbsent(urlKey);
        return base;
      }
      _touch(urlKey);
      return base.copyWith(
        state: AttachmentTransferState.ready,
        localPath: path,
        receivedBytes: row.receivedBytes,
        totalBytes: row.expectedBytes > 0
            ? row.expectedBytes
            : row.receivedBytes,
      );
    }

    // A row still marked in-flight but with no live job means the process died
    // mid-download. The `.part` file survived, so offer a retry — it resumes.
    if ((state == AttachmentTransferState.downloading ||
            state == AttachmentTransferState.queued) &&
        !_queue.isRunning(urlKey)) {
      return base.copyWith(
        state: AttachmentTransferState.failed,
        receivedBytes: row.receivedBytes,
        totalBytes: row.expectedBytes,
        errorMessage: row.lastError,
      );
    }

    return base.copyWith(
      state: state,
      receivedBytes: row.receivedBytes,
      totalBytes: row.expectedBytes > 0
          ? row.expectedBytes
          : attachment.sizeBytes,
      errorMessage: row.lastError,
    );
  }

  /// Current state, then every later change to this attachment.
  Stream<AttachmentHandle> watch(ChatMessageAttachment attachment) {
    final urlKey = attachmentUrlKey(attachment.fileUrl);
    late final StreamController<AttachmentHandle> controller;
    StreamSubscription<AttachmentHandle>? subscription;
    controller = StreamController<AttachmentHandle>(
      onListen: () async {
        if (urlKey.isNotEmpty) {
          subscription = _queue.events
              .where((handle) => handle.urlKey == urlKey)
              .listen(controller.add);
        }
        final current = await resolve(attachment);
        if (!controller.isClosed) controller.add(current);
      },
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  Future<List<AttachmentHandle>> resolveAll(
    List<ChatMessageAttachment> attachments,
  ) => Future.wait(attachments.map(resolve));

  /// Resolve, and download first if it is not on disk. What "open this file"
  /// calls — the caller awaits a usable local path or an error.
  Future<AttachmentHandle> require(ChatMessageAttachment attachment) async {
    final handle = await resolve(attachment);
    if (handle.isReady || handle.isLocked) return handle;
    return _queue.enqueue(attachment, userInitiated: true);
  }

  /// Fire-and-forget download — the badge's tap target.
  void start(ChatMessageAttachment attachment, {bool userInitiated = true}) {
    _queue.enqueue(attachment, userInitiated: userInitiated).ignore();
  }

  void cancel(ChatMessageAttachment attachment) {
    _queue.cancel(attachmentUrlKey(attachment.fileUrl));
  }

  AttachmentTransferState _stateOf(int index) {
    if (index < 0 || index >= AttachmentTransferState.values.length) {
      return AttachmentTransferState.absent;
    }
    return AttachmentTransferState.values[index];
  }

  /// LRU bookkeeping, throttled: a scrolling timeline resolves the same
  /// attachment many times a second and none of those are worth a write.
  void _touch(String urlKey) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastTouchMs[urlKey] ?? 0;
    if (now - last < touchInterval.inMilliseconds) return;
    _lastTouchMs[urlKey] = now;
    _blobs.touch(urlKey).ignore();
  }

  void dispose() => _lastTouchMs.clear();
}
