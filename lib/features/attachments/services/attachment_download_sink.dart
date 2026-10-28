import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../attachment_config.dart';
import 'attachment_cipher.dart';
import 'attachment_failure.dart';

/// Bytes moved, and how far along the whole object that is.
typedef DownloadProgress = void Function(int received, int total);

/// Streams a response body into the sticky `.part` file.
///
/// Chunk-at-a-time through an `IOSink` — the whole point is that a 200 MB
/// video never exists in memory. Progress is throttled here rather than at the
/// UI, so a fast connection cannot push thousands of rebuilds per second
/// through the widget tree.
///
/// Returns the length of the `.part` file afterwards.
Future<int> drainToPart({
  required Stream<List<int>> stream,
  required File partFile,
  required int appendFrom,
  required int total,
  required AttachmentCipher cipher,
  int? maxBytes,
  AttachmentKeyMaterial? key,
  DownloadProgress? onProgress,
}) async {
  final sink = partFile.openWrite(
    mode: appendFrom > 0 ? FileMode.append : FileMode.writeOnly,
  );
  var received = appendFrom;
  var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  var lastFraction = 0.0;
  try {
    if (maxBytes != null && received > maxBytes) throw oversizeFailure;
    final plain = cipher.decode(stream, key, fromOffset: appendFrom);
    await for (final chunk in plain) {
      if (maxBytes != null && received + chunk.length > maxBytes) {
        throw oversizeFailure;
      }
      sink.add(chunk);
      received += chunk.length;
      if (onProgress == null) continue;
      final now = DateTime.now();
      final fraction = total > 0 ? received / total : 0.0;
      final movedEnough = fraction - lastFraction >= progressEmitDelta;
      if (now.difference(lastEmit) >= progressEmitInterval || movedEnough) {
        lastEmit = now;
        lastFraction = fraction;
        onProgress(received, total);
      }
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
  final length = await partFile.exists() ? await partFile.length() : received;
  onProgress?.call(length, total > 0 ? total : length);
  return length;
}

/// Size of the whole object: `Content-Range` on a 206 response, otherwise the
/// body length plus whatever is already on disk. 0 when the server said
/// nothing useful.
int totalBytesFromHeaders(Headers headers, int appendFrom) {
  final range = headers.value('content-range');
  if (range != null && range.contains('/')) {
    final parsed = int.tryParse(range.split('/').last.trim());
    if (parsed != null && parsed > 0) return parsed;
  }
  final length = int.tryParse(headers.value(Headers.contentLengthHeader) ?? '');
  if (length == null || length < 0) return 0;
  return appendFrom + length;
}

Future<void> deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
