import 'dart:io';

import 'package:dio/dio.dart';

/// Why a transfer stopped, and whether trying again could ever help.
class AttachmentDownloadFailure implements Exception {
  const AttachmentDownloadFailure(
    this.code,
    this.message, {
    this.permanent = false,
  });

  final String code;
  final String message;
  final bool permanent;

  @override
  String toString() => 'AttachmentDownloadFailure($code): $message';
}

/// Raised when the caller's byte ceiling (the auto-download cap) is smaller
/// than the object. Not a failure the user should see — the badge just stays
/// on "tap to download".
const oversizeFailure = AttachmentDownloadFailure(
  'too_large',
  'Larger than the automatic download limit',
  permanent: true,
);

/// Maps whatever the transfer threw onto a retry decision.
///
/// Attachment URLs are public and unsigned, so a 403 or 404 is not an auth
/// problem that a refresh could fix — the object is gone (retention purge,
/// discarded upload). Retrying those forever would just burn battery.
AttachmentDownloadFailure classifyDownloadError(Object error) {
  if (error is AttachmentDownloadFailure) return error;

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AttachmentDownloadFailure(
          'timeout',
          'Connection timed out',
        );
      case DioExceptionType.connectionError:
        return const AttachmentDownloadFailure('offline', 'No connection');
      case DioExceptionType.cancel:
        return const AttachmentDownloadFailure('cancelled', 'Cancelled');
      case DioExceptionType.badCertificate:
        return const AttachmentDownloadFailure(
          'bad_certificate',
          'Could not verify the server',
          permanent: true,
        );
      case DioExceptionType.badResponse:
        return _fromStatus(error.response?.statusCode ?? 0);
      case DioExceptionType.unknown:
        return _fromUnknown(error.error ?? error);
    }
  }

  return _fromUnknown(error);
}

AttachmentDownloadFailure _fromStatus(int status) {
  if (status == 408 || status == 429 || status >= 500) {
    return AttachmentDownloadFailure('http_$status', 'Server error ($status)');
  }
  if (status == 401 || status == 403 || status == 404 || status == 410) {
    return AttachmentDownloadFailure(
      'http_$status',
      'This file is no longer available',
      permanent: true,
    );
  }
  return AttachmentDownloadFailure(
    'http_$status',
    'Download failed ($status)',
    permanent: status > 0 && status < 500,
  );
}

AttachmentDownloadFailure _fromUnknown(Object error) {
  if (error is FileSystemException) {
    final message = error.osError?.message.toLowerCase() ?? '';
    final noSpace =
        message.contains('no space') || error.osError?.errorCode == 28;
    return AttachmentDownloadFailure(
      noSpace ? 'no_space' : 'file_system',
      noSpace ? 'Not enough space on this device' : 'Could not write the file',
    );
  }
  if (error is SocketException || error is HttpException) {
    return const AttachmentDownloadFailure('offline', 'No connection');
  }
  return const AttachmentDownloadFailure('unknown', 'Download failed');
}

/// A user-cancelled transfer is neither a failure nor a spent attempt.
bool isCancellation(Object error) =>
    (error is DioException && error.type == DioExceptionType.cancel) ||
    (error is AttachmentDownloadFailure && error.code == 'cancelled');
