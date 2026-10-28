import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/share_routes.dart';
import '../share_progress.dart';
import 'share_endpoint.dart';

enum ShareUploadOutcome { done, failed, unpaired, canceled }

/// Streams one file to the receiver, starting at [offset].
///
/// There is no total timeout — a large file takes as long as it takes. A
/// watchdog aborts the request only when no chunk has left for
/// [ShareLimits.idleTimeout]. A 409 means the receiver holds a different
/// number of bytes than we assumed; the upload restarts from its number.
Future<ShareUploadOutcome> uploadShareFile({
  required HttpClient http,
  required ShareEndpoint to,
  required String messageId,
  required String fileId,
  required String path,
  required int size,
  required int offset,
  required ShareProgressHub progress,
  ShareCancel? cancel,
  int corrections = 2,
}) async {
  final file = File(path);
  if (!await file.exists() || await file.length() != size) {
    return ShareUploadOutcome.failed;
  }
  if (cancel?.canceled ?? false) return ShareUploadOutcome.canceled;

  HttpClientRequest? request;
  Timer? watchdog;
  void abort() => request?.abort();
  void feed() {
    watchdog?.cancel();
    watchdog = Timer(ShareLimits.idleTimeout, abort);
  }

  try {
    request = await http.openUrl(
      'PUT',
      to.uri(ShareRoutes.file(messageId, fileId, offset)),
    );
    cancel?.attach(abort);
    to.sign(request);
    request.headers.contentType = ContentType.binary;
    request.contentLength = size - offset;
    request.bufferOutput = false;

    var sent = offset;
    feed();
    await request.addStream(
      file.openRead(offset).map((chunk) {
        sent += chunk.length;
        progress.report(messageId, fileId, sent);
        feed();
        return chunk;
      }),
    );
    final response = await request.close();
    feed();
    final body = await utf8.decoder.bind(response).join();
    switch (response.statusCode) {
      case HttpStatus.ok:
        progress.report(messageId, fileId, size);
        return ShareUploadOutcome.done;
      case HttpStatus.unauthorized:
        return ShareUploadOutcome.unpaired;
      case HttpStatus.gone:
        return ShareUploadOutcome.canceled;
      case HttpStatus.conflict when corrections > 0:
        final actual = _offsetOf(body);
        if (actual == null || actual > size) return ShareUploadOutcome.failed;
        watchdog?.cancel();
        cancel?.detach(abort);
        return await uploadShareFile(
          http: http,
          to: to,
          messageId: messageId,
          fileId: fileId,
          path: path,
          size: size,
          offset: actual,
          progress: progress,
          cancel: cancel,
          corrections: corrections - 1,
        );
      default:
        return ShareUploadOutcome.failed;
    }
  } catch (_) {
    return (cancel?.canceled ?? false)
        ? ShareUploadOutcome.canceled
        : ShareUploadOutcome.failed;
  } finally {
    watchdog?.cancel();
    cancel?.detach(abort);
  }
}

int? _offsetOf(String body) {
  try {
    final json = jsonDecode(body);
    final offset = json is Map ? json['offset'] : null;
    return offset is int && offset >= 0 ? offset : null;
  } catch (_) {
    return null;
  }
}
