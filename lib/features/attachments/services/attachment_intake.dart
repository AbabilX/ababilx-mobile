import '../../messages/data/models/chat_message.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_ref_store.dart';
import '../data/models/attachment_url_key.dart';
import 'attachment_policy.dart';
import 'attachment_queue.dart';

/// What every arriving message runs through.
///
/// Two jobs: record which blobs a message points at (so deleting it can free
/// the bytes later), and start the downloads that should not wait for a tap.
/// Replaces the old `prefetchImageAttachments`, which fetched images into an
/// opaque HTTP cache that could evict them at any time and gave the UI no way
/// to know whether a file was actually on disk.
class AttachmentIntake {
  AttachmentIntake(this._blobs, this._refs, this._queue);

  final AttachmentBlobStore _blobs;
  final AttachmentRefStore _refs;
  final AttachmentQueue _queue;

  Future<void> onMessages(List<ChatMessage> messages) async {
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

    final started = <String>{};
    for (final message in messages) {
      for (final attachment in message.attachments) {
        if (!shouldAutoDownload(attachment)) continue;
        final urlKey = attachmentUrlKey(attachment.fileUrl);
        if (urlKey.isEmpty || !started.add(urlKey)) continue;
        // Already on disk from an earlier session, or from a forward of the
        // same object — reopening a chat must never re-download.
        if (await _blobs.isReady(urlKey)) continue;
        if (_queue.isRunning(urlKey)) continue;
        _queue.enqueue(attachment).ignore();
      }
    }
  }

  Future<void> onMessage(ChatMessage message) => onMessages([message]);
}
