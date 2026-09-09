import 'dart:io';

import 'dart:convert';

import '../../attachments/data/local/attachment_blob_store.dart';
import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/data/models/attachment_url_key.dart';
import '../../attachments/services/attachment_content_hash.dart';
import '../archive/archive_frames.dart';
import '../archive/gzip_chunker.dart';
import '../data/local/chat_message_row.dart';
import '../data/local/chat_message_store.dart';
import '../data/models/chat_models.dart';
import 'history_transfer_crypto.dart';
import 'history_transfer_manifest.dart';
import 'history_transfer_snapshot.dart';

/// Builds the outbound copy: message chunks sealed onto disk, and a plan
/// saying where every attachment's bytes will sit in the index space.
///
/// Nothing is uploaded here. The plan is written before the first PUT, so a
/// resumed run always agrees with the server about what index k contains.
class HistoryTransferSnapshotBuilder {
  HistoryTransferSnapshotBuilder({
    required this.store,
    required this.blobs,
    required this.snapshot,
    this.onProgress,
  });

  /// 4 MiB of plaintext per chunk — the size the server reserves against, and
  /// small enough that a failed upload re-sends little.
  static const int chunkBytes = 4 * 1024 * 1024;
  static const int _readPage = 500;

  final ChatMessageStore store;
  final AttachmentBlobStore blobs;
  final HistoryTransferSnapshot snapshot;
  final void Function(int messages, int files)? onProgress;

  Future<HistoryTransferPlan> build({
    required String transferId,
    required List<int> transferKey,
    required String deviceId,
    required List<ChatConversation> conversations,
  }) async {
    final gzip = GzipChunker();
    var index = 0;
    var messages = 0;
    final attachments = <String, ChatMessageAttachment>{};
    final messageOf = <String, ChatMessage>{};

    Future<void> flush({required bool finished}) async {
      while (gzip.available >= chunkBytes || (finished && gzip.available > 0)) {
        final sealed = await HistoryTransferCrypto.sealChunk(
          transferKey: transferKey,
          index: index,
          plaintext: gzip.take(chunkBytes),
        );
        await snapshot.messageChunk(index).writeAsBytes(sealed, flush: true);
        index++;
      }
    }

    void writeFrame(ArchiveFrame frame) =>
        gzip.write(utf8.encode('${jsonEncode(frame.toJson())}\n'));

    writeFrame(
      ArchiveFrame.headerFrame(
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        deviceId: deviceId,
      ),
    );
    // Conversations first: the destination must be able to create the row a
    // message points at before the message lands.
    for (final conversation in conversations) {
      writeFrame(ArchiveFrame.conversationFrame(conversation));
    }

    int? afterMs;
    String? afterId;
    while (true) {
      final page = await store.exportPage(
        afterMs: afterMs,
        afterId: afterId,
        limit: _readPage,
      );
      if (page.isEmpty) break;
      for (final message in page) {
        // Pending and failed sends stay on this phone: they are not history
        // yet, the destination cannot finish sending them, and a confirmed
        // copy would arrive later with a different id.
        if (message.isPending || message.id.isEmpty) continue;
        if (!store.deletions.allows(message)) continue;
        writeFrame(ArchiveFrame.messageFrame(message));
        messages++;
        for (final attachment in message.attachments) {
          if (attachment.fileUrl.isEmpty) continue;
          final key = attachmentUrlKey(attachment.fileUrl);
          // First message wins: one file is sent once however many messages
          // forward it, and the destination re-attaches it by url key.
          attachments.putIfAbsent(key, () => attachment);
          messageOf.putIfAbsent(key, () => message);
        }
      }
      await flush(finished: false);
      onProgress?.call(messages, attachments.length);
      final last = page.last;
      afterMs = messageTimeMs(last);
      afterId = localMessageRowId(last);
      if (page.length < _readPage) break;
    }

    writeFrame(ArchiveFrame.endFrame(frames: messages));
    gzip.finish();
    await flush(finished: true);
    final messageChunks = index;

    final files = <HistoryTransferPlannedFile>[];
    for (final entry in attachments.entries) {
      final planned = await _plan(
        urlKey: entry.key,
        attachment: entry.value,
        message: messageOf[entry.key]!,
        nextIndex: index,
      );
      files.add(planned);
      index += planned.chunkCount;
    }

    final plan = HistoryTransferPlan(
      transferId: transferId,
      transferKey: transferKey,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      messageChunkCount: messageChunks,
      messageCount: messages,
      conversationCount: conversations.length,
      files: files,
    );
    await snapshot.writePlan(plan);
    return plan;
  }

  /// One attachment's entry. A file the phone does not hold is recorded as
  /// missing rather than skipped: the destination must be able to say "this
  /// photo is gone" instead of drawing a download that will never finish.
  Future<HistoryTransferPlannedFile> _plan({
    required String urlKey,
    required ChatMessageAttachment attachment,
    required ChatMessage message,
    required int nextIndex,
  }) async {
    final blob = await blobs.read(urlKey);
    final path = blob?.localPath ?? '';
    final ready =
        blob != null &&
        blob.transferState == AttachmentTransferState.ready.index &&
        path.isNotEmpty;
    var bytes = 0;
    var hash = '';
    if (ready) {
      final file = File(path);
      try {
        bytes = await file.length();
        // The store already hashed the file when it landed; re-hashing a
        // 200 MB video for every transfer would cost minutes for nothing.
        hash = (blob.contentHash ?? '').isNotEmpty
            ? blob.contentHash!
            : await hashFileContents(file);
      } catch (_) {
        bytes = 0;
      }
    }
    final available = bytes > 0;
    return HistoryTransferPlannedFile(
      localPath: available ? path : '',
      file: HistoryTransferFile(
        urlKey: urlKey,
        remoteUrl: attachment.fileUrl,
        messageId: message.id,
        conversationId: message.conversationId,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
        sizeBytes: available ? bytes : attachment.sizeBytes,
        sha256: hash,
        firstChunk: available ? nextIndex : -1,
        chunkCount: available ? (bytes + chunkBytes - 1) ~/ chunkBytes : 0,
      ),
    );
  }
}
