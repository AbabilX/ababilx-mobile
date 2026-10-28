import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'attachment_cipher.dart';
import 'attachment_download_sink.dart';
import 'attachment_failure.dart';

export 'attachment_download_sink.dart' show DownloadProgress;

/// Result of one completed transfer.
class DownloadOutcome {
  const DownloadOutcome({required this.file, required this.bytes});

  final File file;
  final int bytes;
}

/// Pulls one R2 object onto disk, streaming, resumable, never buffering the
/// whole file in memory.
///
/// The bytes go network → [AttachmentCipher.decode] → `IOSink` → `.part` file,
/// and only a verified, complete `.part` is renamed onto the final path. A
/// rename on the same filesystem is atomic, so a reader can never observe a
/// half-written attachment as ready.
class AttachmentDownloader {
  AttachmentDownloader(this._dio, this._cipher);

  final Dio _dio;
  final AttachmentCipher _cipher;

  /// [expectedBytes] is the server-verified size (0 when unknown).
  /// [maxBytes] aborts on the response header — how an automatic download
  /// refuses an object that turned out to be larger than the cap.
  Future<DownloadOutcome> fetch({
    required String remoteUrl,
    required File target,
    required File partFile,
    int expectedBytes = 0,
    int? maxBytes,
    AttachmentKeyMaterial? key,
    CancelToken? cancelToken,
    DownloadProgress? onProgress,
  }) async {
    try {
      return await _attempt(
        remoteUrl: remoteUrl,
        target: target,
        partFile: partFile,
        expectedBytes: expectedBytes,
        maxBytes: maxBytes,
        key: key,
        cancelToken: cancelToken,
        onProgress: onProgress,
        allowRangeRestart: true,
      );
    } on _RangeRejected {
      // The server disowned our partial file (416). Drop it and start over —
      // once. A second 416 with no `.part` present is a real failure.
      await deleteQuietly(partFile);
      return _attempt(
        remoteUrl: remoteUrl,
        target: target,
        partFile: partFile,
        expectedBytes: expectedBytes,
        maxBytes: maxBytes,
        key: key,
        cancelToken: cancelToken,
        onProgress: onProgress,
        allowRangeRestart: false,
      );
    }
  }

  Future<DownloadOutcome> _attempt({
    required String remoteUrl,
    required File target,
    required File partFile,
    required int expectedBytes,
    required int? maxBytes,
    required AttachmentKeyMaterial? key,
    required CancelToken? cancelToken,
    required DownloadProgress? onProgress,
    required bool allowRangeRestart,
  }) async {
    var startAt = 0;
    if (_cipher.supportsResume && await partFile.exists()) {
      startAt = await partFile.length();
    } else if (await partFile.exists()) {
      // A cipher that cannot decode a partial stream forces a clean start.
      await deleteQuietly(partFile);
    }

    final response = await _dio.get<ResponseBody>(
      remoteUrl,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: startAt > 0 ? {'Range': 'bytes=$startAt-'} : null,
        validateStatus: (status) =>
            status == 200 || status == 206 || status == 416,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 416) {
      if (!allowRangeRestart) {
        throw const AttachmentDownloadFailure(
          'range_rejected',
          'This file changed on the server',
        );
      }
      throw const _RangeRejected();
    }

    // Asked to resume and got a whole body back: the server ignored Range, so
    // appending would corrupt the file. Overwrite from zero instead.
    var appendFrom = startAt;
    if (status == 200) appendFrom = 0;

    final total = totalBytesFromHeaders(response.headers, appendFrom);
    if (expectedBytes > 0 && total > 0 && total != expectedBytes) {
      throw const AttachmentDownloadFailure(
        'size_mismatch',
        'This file does not match what the server described',
        permanent: true,
      );
    }
    if (maxBytes != null && total > maxBytes) throw oversizeFailure;

    final int written;
    try {
      written = await drainToPart(
        stream: response.data!.stream,
        partFile: partFile,
        appendFrom: appendFrom,
        total: total,
        maxBytes: maxBytes,
        cipher: _cipher,
        key: key,
        onProgress: onProgress,
      );
    } on AttachmentDownloadFailure {
      await deleteQuietly(partFile);
      rethrow;
    }

    if (expectedBytes > 0 && written != expectedBytes) {
      await deleteQuietly(partFile);
      throw const AttachmentDownloadFailure(
        'size_mismatch',
        'This file does not match what the server described',
        permanent: true,
      );
    }
    if (total > 0 && written != total) {
      await deleteQuietly(partFile);
      throw const AttachmentDownloadFailure(
        'truncated',
        'The download ended early',
      );
    }

    if (await target.exists()) await deleteQuietly(target);
    final finished = await partFile.rename(target.path);
    return DownloadOutcome(file: finished, bytes: written);
  }
}

/// Internal signal: HTTP 416, our partial file is no longer valid.
class _RangeRejected implements Exception {
  const _RangeRejected();
}
