import 'dart:convert';
import 'dart:typed_data';

import 'v2_crypto.dart';
import 'v2_media_source.dart';
import 'v2_plan.dart';

/// Builds and seals one batch's descriptor (protocol section 4.3): the JSON is
/// split into slices of at most 786,400 bytes and each slice sealed with the page
/// AAD, which binds its index AND the page count — a relay that drops the last
/// page makes every page fail, not just the missing one.
class V2Descriptor {
  V2Descriptor._();

  // 786400 plaintext bytes + 12-byte nonce + 16-byte tag encode to 1,048,571
  // base64url characters, below the server's 1 MiB encoded-value limit.
  static const int slicePlainBytes = 786400;
  static const int maxPages = 32;

  static Future<Map<String, dynamic>> build({
    required V2Plan plan,
    required V2PlannedBatch batch,
    required V2MediaSource media,
    required List<Map<String, dynamic>> deletions,
  }) async {
    final files = <Map<String, dynamic>>[];
    if (batch.kind == 'media') {
      for (final file in plan.filesIn(batch.batch)) {
        final segments = file.segments
            .where((s) => s.batch == batch.batch)
            .toList();
        final hashes = <String?>[
          for (final seg in segments) await media.segmentHash(file, seg),
        ];
        final omitted =
            file.status != 'available' || hashes.any((hash) => hash == null);
        for (var i = 0; i < segments.length; i++) {
          final seg = segments[i];
          final hash = hashes[i];
          files.add({
            ..._fileJson(file),
            'status': omitted ? 'omitted' : 'available',
            'seg': seg.seg,
            'segs': seg.segs,
            'file_offset': seg.fileOffset,
            'length': seg.length,
            'stream_offset': seg.streamOffset,
            'seg_sha256': omitted ? '' : hash,
          });
        }
      }
    }
    if (batch.isFinal) {
      for (final file in plan.files.where((f) => f.status == 'missing')) {
        files.add({..._fileJson(file), 'status': 'missing'});
      }
    }
    return {
      'v': HistoryTransferV2Crypto.version,
      'transfer_id': plan.transferId,
      'batch': batch.batch,
      'kind': batch.kind,
      'final': batch.isFinal,
      'chunk_count': batch.chunkCount,
      'stream_bytes': batch.streamBytes,
      'stream_sha256': batch.streamSha256,
      'messages': batch.messages,
      'conversations': batch.conversations,
      'deletions': deletions,
      'files': files,
    };
  }

  static Map<String, dynamic> _fileJson(V2File file) => {
    'url_key': file.urlKey,
    'sha256': file.sha256,
    'size': file.size,
    'file_name': file.fileName,
    'content_type': file.contentType,
  };

  static Future<List<String>> seal({
    required List<int> key,
    required String transferId,
    required int batch,
    required Map<String, dynamic> descriptor,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(descriptor)));
    final count = bytes.isEmpty
        ? 1
        : (bytes.length + slicePlainBytes - 1) ~/ slicePlainBytes;
    if (count > maxPages) {
      throw StateError('descriptor for batch $batch needs $count pages');
    }
    return [
      for (var i = 0; i < count; i++)
        await HistoryTransferV2Crypto.seal(
          key,
          HistoryTransferV2Crypto.pageAad(transferId, batch, i, count),
          bytes.sublist(
            i * slicePlainBytes,
            (i + 1) * slicePlainBytes < bytes.length
                ? (i + 1) * slicePlainBytes
                : bytes.length,
          ),
        ).then(_b64),
    ];
  }

  static String _b64(Uint8List bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
