import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

import '../../messages/data/models/chat_attachment.dart';
import '../services/attachment_download_sink.dart';
import '../services/attachment_downloader.dart';
import '../services/attachment_failure.dart';
import '../services/attachment_paths.dart';
import 'attachment_crypto_format.dart';
import 'attachment_file_cipher.dart';
import 'attachment_secret.dart';

/// Suffixes of the two files an encrypted download passes through on its way
/// to [target]. Both sit beside it, so the final rename stays on one
/// filesystem and is atomic.
const _cipherSuffix = '.enc';
const _stagingSuffix = '.dec';

/// Brings one attachment onto disk as a readable file, whichever way it is
/// stored on the server.
///
/// A plaintext object is streamed straight into place, as before. An
/// encrypted one (server 0168) is downloaded as it is — so a dropped
/// connection resumes on ciphertext bytes, exactly like any other download —
/// and only a complete object is decrypted, into a staging file that is
/// renamed over [target] once every chunk has authenticated. A reader can
/// therefore never see a half-decrypted file, and nothing unauthenticated is
/// ever written where a renderer looks.
Future<DownloadOutcome> fetchAttachment(
  AttachmentDownloader downloader,
  AttachmentPaths paths,
  ChatMessageAttachment attachment, {
  required File target,
  int? maxBytes,
  CancelToken? cancelToken,
  DownloadProgress? onProgress,
}) {
  // The queue turns these away before a job starts; this is the backstop for
  // any other caller. Not permanent — the next unlock or key backfill makes
  // the same download succeed.
  if (attachment.needsKey) {
    throw const AttachmentDownloadFailure(
      'needs_key',
      'This file cannot be opened on this phone yet',
    );
  }
  final secret = attachment.secret;
  if (secret == null) {
    return downloader.fetch(
      remoteUrl: attachment.fileUrl,
      target: target,
      partFile: paths.partFor(target),
      expectedBytes: attachment.sizeBytes,
      maxBytes: maxBytes,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  }
  return _fetchSealed(
    downloader,
    paths,
    attachment.fileUrl,
    secret,
    target: target,
    maxBytes: maxBytes,
    cancelToken: cancelToken,
    onProgress: onProgress,
  );
}

Future<DownloadOutcome> _fetchSealed(
  AttachmentDownloader downloader,
  AttachmentPaths paths,
  String remoteUrl,
  AttachmentSecret secret, {
  required File target,
  int? maxBytes,
  CancelToken? cancelToken,
  DownloadProgress? onProgress,
}) async {
  final cipher = File('${target.path}$_cipherSuffix');
  final staging = File('${target.path}$_stagingSuffix');
  final downloaded = await downloader.fetch(
    remoteUrl: remoteUrl,
    target: cipher,
    partFile: paths.partFor(cipher),
    expectedBytes: secret.cipherSize,
    // The ceiling is on the file; the object is padded and tagged past it.
    maxBytes: maxBytes == null
        ? null
        : AttachmentCryptoFormat.cipherSize(maxBytes),
    cancelToken: cancelToken,
    onProgress: onProgress,
  );
  try {
    await AttachmentFileCipher.openFile(
      downloaded.file,
      staging,
      secret.key,
      secret.plainSize,
    );
    if (await target.exists()) await deleteQuietly(target);
    final finished = await staging.rename(target.path);
    return DownloadOutcome(file: finished, bytes: secret.plainSize);
  } on SecretBoxAuthenticationError {
    throw _unreadable;
  } on AttachmentCipherException {
    throw _unreadable;
  } finally {
    await deleteQuietly(cipher);
    await deleteQuietly(staging);
  }
}

/// The whole object arrived and still does not open under its key. Fetching
/// the same bytes again cannot change that, so it is not retried.
const _unreadable = AttachmentDownloadFailure(
  'undecryptable',
  'This file could not be opened',
  permanent: true,
);
