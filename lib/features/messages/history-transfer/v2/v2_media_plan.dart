import 'dart:io';

import '../../../attachments/data/local/attachment_blob_store.dart';
import '../../../attachments/data/models/attachment_handle.dart';
import '../../../attachments/data/models/attachment_url_key.dart';
import '../../../attachments/services/attachment_content_hash.dart';
import '../../data/models/chat_models.dart';
import 'v2_plan.dart';

/// A file the destination already holds verified; the phone skips it entirely.
typedef V2HeldFile = ({String urlKey, String sha256, int size});

/// Lays every attachment's bytes out across media batches.
///
/// A media batch's stream is its files' bytes back to back, so a thousand
/// voice notes cost a few dozen 4 MiB uploads rather than a thousand requests.
/// A file longer than what is left of a batch continues in the next one as its
/// next segment. Files the phone does not hold are recorded as `missing` so the
/// destination can say so instead of waiting for them.
class V2MediaPlanner {
  V2MediaPlanner({
    required this.blobs,
    this.held = const [],
    this.batchPlainBytes = 64 * 4 * 1024 * 1024,
    this.maxFilesPerBatch = 20000,
  });

  final AttachmentBlobStore blobs;
  final List<V2HeldFile> held;
  final int batchPlainBytes;
  final int maxFilesPerBatch;

  Future<({List<V2File> files, List<V2PlannedBatch> batches})> plan(
    Iterable<ChatMessageAttachment> attachments,
    int firstBatch,
  ) async {
    final files = <String, V2File>{};
    for (final attachment in attachments) {
      final key = attachmentUrlKey(attachment.fileUrl);
      if (key.isEmpty || files.containsKey(key)) continue;
      final file = await _describe(key, attachment);
      if (file == null) continue;
      files[key] = file;
    }
    final batches = _layout(files.values.where((f) => f.status == 'available'), firstBatch);
    return (files: files.values.toList(), batches: batches);
  }

  Future<V2File?> _describe(String key, ChatMessageAttachment attachment) async {
    final blob = await blobs.read(key);
    final path = blob?.localPath ?? '';
    final ready = blob != null &&
        blob.transferState == AttachmentTransferState.ready.index &&
        path.isNotEmpty;
    if (ready) {
      try {
        final file = File(path);
        final stat = await file.stat();
        if (stat.type == FileSystemEntityType.file) {
          // The store hashed the file when it landed; re-hashing a long video
          // for every transfer would cost minutes for nothing.
          final hash = (blob.contentHash ?? '').isNotEmpty
              ? blob.contentHash!
              : await hashFileContents(file);
          if (held.any((h) => h.urlKey == key && h.sha256 == hash && h.size == stat.size)) {
            return null;
          }
          return V2File(
            urlKey: key,
            fileName: attachment.fileName,
            contentType: attachment.contentType,
            size: stat.size,
            sha256: hash,
            localPath: path,
            mtimeMs: stat.modified.millisecondsSinceEpoch,
            status: 'available',
          );
        }
      } catch (_) {
        // Unreadable now is missing, not an error for the whole transfer.
      }
    }
    return V2File(
      urlKey: key,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      size: attachment.sizeBytes,
      sha256: '',
      localPath: '',
      mtimeMs: 0,
      status: 'missing',
    );
  }

  List<V2PlannedBatch> _layout(Iterable<V2File> files, int firstBatch) {
    final sizes = <int, int>{};
    var batch = firstBatch;
    var offset = 0;
    var entries = 0;
    void next() {
      batch++;
      offset = 0;
      entries = 0;
    }

    for (final file in files) {
      final segments = <V2Segment>[];
      var fileOffset = 0;
      var remaining = file.size;
      do {
        if (entries >= maxFilesPerBatch || (offset >= batchPlainBytes && remaining > 0)) next();
        final take = remaining < batchPlainBytes - offset ? remaining : batchPlainBytes - offset;
        segments.add(V2Segment(
          batch: batch,
          seg: segments.length,
          segs: 0,
          fileOffset: fileOffset,
          length: take,
          streamOffset: offset,
        ));
        offset += take;
        fileOffset += take;
        remaining -= take;
        entries++;
        sizes[batch] = offset;
      } while (remaining > 0);
      file.segments = [
        for (final s in segments)
          V2Segment(
            batch: s.batch,
            seg: s.seg,
            segs: segments.length,
            fileOffset: s.fileOffset,
            length: s.length,
            streamOffset: s.streamOffset,
          ),
      ];
    }
    const chunk = 4 * 1024 * 1024;
    return [
      for (final entry in sizes.entries)
        V2PlannedBatch(
          batch: entry.key,
          kind: 'media',
          isFinal: false,
          chunkCount: (entry.value + chunk - 1) ~/ chunk,
          streamBytes: entry.value,
        ),
    ];
  }
}
