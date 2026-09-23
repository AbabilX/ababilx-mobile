import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../archive/gzip_chunker.dart';
import '../../data/local/chat_message_row.dart';
import '../../data/local/chat_message_store.dart';
import '../../data/models/chat_models.dart';
import 'v2_conversations.dart';
import 'v2_crypto.dart';
import 'v2_plan.dart';
import 'v2_store.dart';

/// Seals every confirmed message on this phone into v2 message batches on
/// disk. No age cutoff: the phone is the archive, and anything older than the
/// server's six months is exactly what the destination is missing.
///
/// Each batch is one gzip member of NDJSON frames — header, a `conv` frame
/// before the first message that names it, messages oldest first, `end` — so a
/// batch activates on its own. A batch closes once its gzip output reaches the
/// target; the next one repeats the header and its own `conv` frames.
class V2MessageBatchBuilder {
  V2MessageBatchBuilder({
    required this.messages,
    required this.store,
    required this.transferId,
    required this.transferKey,
    required this.conversations,
    this.targetChunks = 64,
    this.onProgress,
  });

  static const int chunkBytes = 4 * 1024 * 1024;
  static const int _readPage = 500;

  final ChatMessageStore messages;
  final V2Store store;
  final String transferId;
  final List<int> transferKey;
  final V2Conversations conversations;
  final int targetChunks;
  final void Function(int messages)? onProgress;

  /// Files referenced by exported messages, first message wins — one file is
  /// sent once however many messages forward it.
  final Map<String, ChatMessageAttachment> attachments = {};
  int messageCount = 0;

  late _OpenBatch _open;
  final List<V2PlannedBatch> _batches = [];

  Future<List<V2PlannedBatch>> build() async {
    _start(0);
    int? afterMs;
    String? afterId;
    while (true) {
      final page = await messages.exportPage(
        afterMs: afterMs,
        afterId: afterId,
        limit: _readPage,
      );
      if (page.isEmpty) break;
      for (final message in page) {
        // Pending and failed sends stay here: not history yet, and their
        // confirmed copy would arrive later under a different id.
        if (message.isPending || message.id.isEmpty) continue;
        if (!messages.deletions.allows(message)) continue;
        _add(message);
      }
      await _flush(finished: false);
      onProgress?.call(messageCount);
      if (_open.full(targetChunks)) {
        await _close();
        _start(_batches.length);
      }
      afterMs = messageTimeMs(page.last);
      afterId = localMessageRowId(page.last);
      if (page.length < _readPage) break;
    }
    await _close();
    return _batches;
  }

  void _start(int batch) {
    _open = _OpenBatch(batch);
    _write({
      't': 'header',
      'v': HistoryTransferV2Crypto.version,
      'transfer_id': transferId,
      'batch': batch,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _add(ChatMessage message) {
    final id = message.conversationId;
    if (_open.conversations.add(id)) {
      _write({'t': 'conv', 'c': conversations.frameFor(id, message)});
    }
    final json = message.toJson()
      ..remove('send_status')
      ..removeWhere((key, _) => key.startsWith('pending_'));
    _write({'t': 'msg', 'm': json});
    _open.messages++;
    messageCount++;
    for (final attachment in message.attachments) {
      if (attachment.fileUrl.isEmpty) continue;
      attachments.putIfAbsent(attachment.fileUrl, () => attachment);
    }
  }

  void _write(Map<String, dynamic> frame) =>
      _open.gzip.write(utf8.encode('${jsonEncode(frame)}\n'));

  Future<void> _flush({required bool finished}) async {
    final gzip = _open.gzip;
    while (gzip.available >= chunkBytes || (finished && gzip.available > 0)) {
      final plain = gzip.take(chunkBytes);
      _open.hash.add(plain);
      _open.streamBytes += plain.length;
      final sealed = await HistoryTransferV2Crypto.seal(
        transferKey,
        HistoryTransferV2Crypto.chunkAad(
          transferId,
          _open.batch,
          'messages',
          _open.chunks,
        ),
        plain,
      );
      await store.batchDir(_open.batch).create(recursive: true);
      await store
          .chunkFile(_open.batch, _open.chunks)
          .writeAsBytes(sealed, flush: true);
      _open.chunks++;
    }
  }

  Future<void> _close() async {
    _write({
      't': 'end',
      'messages': _open.messages,
      'conversations': _open.conversations.length,
    });
    _open.gzip.finish();
    await _flush(finished: true);
    _open.hash.close();
    _batches.add(
      V2PlannedBatch(
        batch: _open.batch,
        kind: 'messages',
        isFinal: false,
        chunkCount: _open.chunks,
        streamBytes: _open.streamBytes,
        streamSha256: _open.digest.value.toString(),
        messages: _open.messages,
        conversations: _open.conversations.length,
      ),
    );
  }
}

class _OpenBatch {
  _OpenBatch(this.batch) {
    hash = sha256.startChunkedConversion(digest);
  }

  final int batch;
  final GzipChunker gzip = GzipChunker();
  final _DigestSink digest = _DigestSink();
  late final ByteConversionSink hash;
  final Set<String> conversations = {};
  int messages = 0;
  int chunks = 0;
  int streamBytes = 0;

  bool full(int targetChunks) =>
      chunks * V2MessageBatchBuilder.chunkBytes + gzip.available >=
      targetChunks * V2MessageBatchBuilder.chunkBytes;
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
