import 'dart:convert';

import '../data/local/chat_message_row.dart';
import '../data/local/chat_message_store.dart';
import '../data/models/chat_models.dart';
import 'archive_api.dart';
import 'archive_frames.dart';
import 'archive_key.dart';
import 'archive_writer.dart';

/// Streams the device's history into a sealed archive on the server.
///
/// Reads through [ChatMessageArchiveSource.exportPage], never `page`: the
/// screen read filters `thread_root_id IS NULL` and would silently omit every
/// thread reply from the backup.
///
/// Chunks upload as they are sealed, so peak memory is one chunk rather than
/// one history, and a phone with 200 000 messages costs the same as one with
/// 200.
class ArchiveExporter {
  ArchiveExporter({
    required this.store,
    required this.api,
    required this.identityScalar,
    this.onProgress,
  });

  final ChatMessageStore store;
  final ArchiveApi api;

  /// The account identity's 32-byte private scalar. Present on every unlocked
  /// device — see [ArchiveKey] for why the recovery code cannot be used here.
  final List<int> identityScalar;

  final void Function(int framesWritten)? onProgress;

  static const _readPage = 500;

  Future<ArchiveExportResult> run({
    required String deviceId,
    required int createdAtMs,
    List<ChatConversation> conversations = const [],
  }) async {
    final salt = ArchiveKey.newSalt();
    final key = await ArchiveKey.derive(identityScalar, salt);
    final generation = await api.begin(
      base64Url.encode(salt).replaceAll('=', ''),
    );

    var uploaded = 0;
    final writer = ArchiveWriter(
      key: key,
      onChunk: (index, chunk) async {
        // nonce first, then ciphertext: the reader splits on a fixed 12 bytes,
        // so the layout is part of the format and must not be reordered.
        final body = <int>[...chunk.nonce, ...chunk.ciphertext];
        final url = await api.presignChunk(
          generation: generation,
          index: index,
          sizeBytes: body.length,
        );
        await api.putChunk(url, body);
        uploaded += body.length;
      },
    );

    await writer.add(
      ArchiveFrame.headerFrame(createdAtMs: createdAtMs, deviceId: deviceId),
    );
    // Conversations first: an importer must be able to create the row a
    // message points at before the message arrives.
    for (final conversation in conversations) {
      await writer.add(ArchiveFrame.conversationFrame(conversation));
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
        await writer.add(ArchiveFrame.messageFrame(message));
      }
      onProgress?.call(writer.framesWritten);
      final last = page.last;
      afterMs = messageTimeMs(last);
      afterId = localMessageRowId(last);
      if (page.length < _readPage) break;
    }

    await writer.close();
    await api.commit(
      generation: generation,
      chunkCount: writer.chunksWritten,
      totalBytes: uploaded,
      formatVersion: archiveFormatVersion,
    );
    return ArchiveExportResult(
      generation: generation,
      frames: writer.framesWritten,
      chunks: writer.chunksWritten,
      bytes: uploaded,
    );
  }
}

class ArchiveExportResult {
  const ArchiveExportResult({
    required this.generation,
    required this.frames,
    required this.chunks,
    required this.bytes,
  });

  final int generation;
  final int frames;
  final int chunks;
  final int bytes;
}
