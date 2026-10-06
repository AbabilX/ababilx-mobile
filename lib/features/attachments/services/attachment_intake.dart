import '../../messages/data/models/chat_message.dart';
import '../attachment_config.dart';
import '../auto_download/auto_download_gate.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_ref_store.dart';
import '../data/models/attachment_handle.dart';
import '../data/models/attachment_url_key.dart';
import 'attachment_queue.dart';

/// What every arriving message runs through.
///
/// Three jobs: record which blobs a message points at (so deleting it can
/// free the bytes later), start the downloads that should not wait for a tap,
/// and silently retry ones that failed while the app was closed or killed —
/// a process death mid-download leaves a row stuck `downloading`/`queued`
/// with no job behind it, and a transient failure leaves one `failed`. Either
/// way the user should not have to find the message and tap retry themselves.
/// Replaces the old `prefetchImageAttachments`, which fetched images into an
/// opaque HTTP cache that could evict them at any time and gave the UI no way
/// to know whether a file was actually on disk.
class AttachmentIntake {
  AttachmentIntake(
    this._blobs,
    this._refs,
    this._queue,
    this._gate, {
    bool Function(String conversationId)? isLocked,
  }) : _isLocked = isLocked ?? _never;

  final AttachmentBlobStore _blobs;
  final AttachmentRefStore _refs;
  final AttachmentQueue _queue;
  final AutoDownloadGate _gate;

  /// A locked chat's files are held in memory only (chat lock), so nothing
  /// arriving in one is indexed, downloaded or retried here.
  final bool Function(String conversationId) _isLocked;

  static bool _never(String _) => false;
  final Map<String, int> _lastRetryMs = {};

  Future<void> onMessages(List<ChatMessage> all) async {
    final messages = [
      for (final m in all)
        if (!_isLocked(m.conversationId)) m,
    ];
    final entries = <AttachmentRefEntry>[];
    for (final message in messages) {
      for (final attachment in message.attachments) {
        if (attachment.locked || attachment.fileUrl.isEmpty) continue;
        final urlKey = attachmentUrlKey(attachment.fileUrl);
        if (urlKey.isEmpty) continue;
        entries.add(
          AttachmentRefEntry(
            attachmentId: attachment.id,
            urlKey: urlKey,
            messageId: message.id,
            conversationId: message.conversationId,
          ),
        );
      }
    }
    if (entries.isEmpty) return;
    await _refs.indexAll(entries);

    // Resolved once for the whole batch: the settings read and the network
    // probe are both awaits, and a screenful of arriving messages must not pay
    // for them per attachment — nor end up with two attachments of the same
    // message judged against different answers.
    final decision = await _gate.resolve();

    final started = <String>{};
    for (final message in messages) {
      for (final attachment in message.attachments) {
        // Encrypted, and its key did not open here (vault locked, or a key
        // version this account does not hold): nothing readable to fetch.
        if (attachment.needsKey) continue;
        if (!decision.allows(attachment)) continue;
        final urlKey = attachmentUrlKey(attachment.fileUrl);
        if (urlKey.isEmpty || !started.add(urlKey)) continue;
        if (_queue.isRunning(urlKey)) continue;
        if (!await _shouldStart(urlKey)) continue;
        _queue.enqueue(attachment).ignore();
      }
    }
  }

  Future<void> onMessage(ChatMessage message) => onMessages([message]);

  /// Decides whether an auto-eligible attachment with no job currently
  /// running for it is worth starting.
  Future<bool> _shouldStart(String urlKey) async {
    final row = await _blobs.read(urlKey);
    // Never seen before — a plain first download.
    if (row == null) return true;

    switch (attachmentTransferStateFromIndex(row.transferState)) {
      // Already on disk, or not worth retrying — leave alone. Reopening a
      // chat must never re-download, and a permanent failure (object gone)
      // would just fail again.
      case AttachmentTransferState.ready:
      case AttachmentTransferState.permanentlyFailed:
      case AttachmentTransferState.locked:
        return false;
      // Retryable failure, or a transfer that never got to finish because the
      // process died mid-download — both are silently retried, rate-limited
      // so a burst of incoming messages cannot hammer the same failed job.
      case AttachmentTransferState.failed:
      case AttachmentTransferState.downloading:
      case AttachmentTransferState.queued:
      case AttachmentTransferState.absent:
        return _dueForRetry(urlKey);
    }
  }

  bool _dueForRetry(String urlKey) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastRetryMs[urlKey];
    if (last != null && now - last < autoRetryCooldown.inMilliseconds) {
      return false;
    }
    _lastRetryMs[urlKey] = now;
    return true;
  }
}
