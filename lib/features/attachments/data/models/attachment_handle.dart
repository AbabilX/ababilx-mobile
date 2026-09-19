import 'dart:io';

import 'package:equatable/equatable.dart';

import 'media_dimensions.dart';

/// Where an attachment's bytes are, from the renderer's point of view.
///
/// Persisted as an int (`AttachmentBlobs.transferState`) so a future state is
/// a value, not a migration.
enum AttachmentTransferState {
  /// Nothing on disk. Either never fetched, evicted, or the file vanished.
  absent,

  /// Accepted by the queue, waiting on a concurrency slot.
  queued,

  /// Bytes are moving.
  downloading,

  /// [AttachmentHandle.localPath] is a complete, verified file.
  ready,

  /// Retryable failure — the badge offers a retry, and the sticky `.part`
  /// means that retry resumes.
  failed,

  /// Not worth retrying (object gone, size mismatch twice). No affordance.
  permanentlyFailed,

  /// Withheld by free-plan retention: the server sends no URL at all.
  locked,
}

/// Safe decode of the persisted int — an out-of-range value (a row written by
/// a future version, or corruption) falls back to [AttachmentTransferState.absent]
/// rather than throwing.
AttachmentTransferState attachmentTransferStateFromIndex(int index) {
  if (index < 0 || index >= AttachmentTransferState.values.length) {
    return AttachmentTransferState.absent;
  }
  return AttachmentTransferState.values[index];
}

/// The one thing every renderer is handed. It answers "can I draw this yet,
/// and from where" without any caller ever seeing a remote URL.
class AttachmentHandle extends Equatable {
  const AttachmentHandle({
    required this.urlKey,
    required this.remoteUrl,
    required this.state,
    this.fileName = '',
    this.contentType = '',
    this.localPath,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage = '',
    this.dimensions,
  });

  const AttachmentHandle.locked({this.fileName = ''})
    : urlKey = '',
      remoteUrl = '',
      state = AttachmentTransferState.locked,
      contentType = '',
      localPath = null,
      receivedBytes = 0,
      totalBytes = 0,
      errorMessage = '',
      dimensions = null;

  final String urlKey;
  final String remoteUrl;
  final AttachmentTransferState state;
  final String fileName;
  final String contentType;
  final String? localPath;
  final int receivedBytes;
  final int totalBytes;
  final String errorMessage;

  /// The picture's (or a video poster's) drawn size, once it has been
  /// measured from the local file. Kept through eviction, so a photo that is
  /// downloading again still knows its shape. Null when never measured.
  final MediaDimensions? dimensions;

  File? get file {
    final path = localPath;
    return path == null || path.isEmpty ? null : File(path);
  }

  bool get isReady =>
      state == AttachmentTransferState.ready &&
      localPath != null &&
      localPath!.isNotEmpty;

  bool get isBusy =>
      state == AttachmentTransferState.queued ||
      state == AttachmentTransferState.downloading;

  bool get canRetry => state == AttachmentTransferState.failed;

  bool get isLocked => state == AttachmentTransferState.locked;

  /// 0..1, or 0 while the total is still unknown (the badge shows an
  /// indeterminate ring in that case).
  double get progress {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  AttachmentHandle copyWith({
    AttachmentTransferState? state,
    String? localPath,
    bool clearLocalPath = false,
    int? receivedBytes,
    int? totalBytes,
    String? errorMessage,
    MediaDimensions? dimensions,
  }) {
    return AttachmentHandle(
      urlKey: urlKey,
      remoteUrl: remoteUrl,
      state: state ?? this.state,
      fileName: fileName,
      contentType: contentType,
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      dimensions: dimensions ?? this.dimensions,
    );
  }

  @override
  List<Object?> get props => [
    urlKey,
    state,
    localPath,
    receivedBytes,
    totalBytes,
    errorMessage,
    dimensions,
  ];
}
