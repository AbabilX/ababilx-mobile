import 'package:equatable/equatable.dart';

import 'file_dto.dart';
import 'session_state.dart';

enum TransferDirection { sent, received }

/// One completed (or failed/canceled) file transfer, persisted for the
/// History tab. Built from a terminal [FileTransferProgress] inside a
/// finished [ShareSessionState].
class TransferRecord extends Equatable {
  final String id;
  final TransferDirection direction;
  final String peerAlias;
  final String peerFingerprint;
  final String fileName;
  final int size;
  final LocalFileType fileType;
  final String? path;
  final FileStatus status;
  final DateTime timestamp;

  const TransferRecord({
    required this.id,
    required this.direction,
    required this.peerAlias,
    required this.peerFingerprint,
    required this.fileName,
    required this.size,
    required this.fileType,
    required this.path,
    required this.status,
    required this.timestamp,
  });

  factory TransferRecord.fromSession(
    ShareSessionState session,
    FileTransferProgress progress,
  ) {
    return TransferRecord(
      id: '${session.sessionId}_${progress.file.id}',
      direction: session.isOutgoing
          ? TransferDirection.sent
          : TransferDirection.received,
      peerAlias: session.targetDevice.alias,
      peerFingerprint: session.targetDevice.fingerprint,
      fileName: progress.file.fileName,
      size: progress.file.size,
      fileType: progress.file.fileType,
      path: progress.file.filePath,
      status: progress.status,
      timestamp: session.startTime,
    );
  }

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    return TransferRecord(
      id: json['id'] as String,
      direction: json['direction'] == 'sent'
          ? TransferDirection.sent
          : TransferDirection.received,
      peerAlias: json['peerAlias'] as String? ?? 'Unknown Device',
      peerFingerprint: json['peerFingerprint'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'file',
      size: json['size'] as int? ?? 0,
      fileType: LocalFileType.parse(json['fileType'] as String? ?? 'other'),
      path: json['path'] as String?,
      status: FileStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FileStatus.finished,
      ),
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'direction': direction == TransferDirection.sent ? 'sent' : 'received',
      'peerAlias': peerAlias,
      'peerFingerprint': peerFingerprint,
      'fileName': fileName,
      'size': size,
      'fileType': fileType.toJsonString(),
      'path': path,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    direction,
    peerAlias,
    peerFingerprint,
    fileName,
    size,
    fileType,
    path,
    status,
    timestamp,
  ];
}
