import 'package:equatable/equatable.dart';
import 'device_model.dart';
import 'file_dto.dart';

enum TransferSessionStatus {
  idle,
  waitingForRecipient,
  sending,
  receiving,
  finished,
  declined,
  canceled,
  error,
}

enum FileStatus {
  queue,
  transferring,
  finished,
  failed,
  canceled,
}

class FileTransferProgress extends Equatable {
  final LocalFileDto file;
  final FileStatus status;
  final int bytesTransferred;
  final String? errorMessage;

  const FileTransferProgress({
    required this.file,
    this.status = FileStatus.queue,
    this.bytesTransferred = 0,
    this.errorMessage,
  });

  double get progress => file.size == 0 ? 0.0 : (bytesTransferred / file.size).clamp(0.0, 1.0);

  FileTransferProgress copyWith({
    LocalFileDto? file,
    FileStatus? status,
    int? bytesTransferred,
    String? errorMessage,
  }) {
    return FileTransferProgress(
      file: file ?? this.file,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [file, status, bytesTransferred, errorMessage];
}

class ShareSessionState extends Equatable {
  final String sessionId;
  final LocalDevice targetDevice;
  final bool isOutgoing;
  final TransferSessionStatus status;
  final Map<String, FileTransferProgress> files; // fileId -> progress
  final String? errorMessage;
  final DateTime startTime;

  ShareSessionState({
    required this.sessionId,
    required this.targetDevice,
    required this.isOutgoing,
    this.status = TransferSessionStatus.idle,
    required this.files,
    this.errorMessage,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  int get totalBytes => files.values.fold(0, (sum, item) => sum + item.file.size);
  int get transferredBytes => files.values.fold(0, (sum, item) => sum + item.bytesTransferred);
  double get overallProgress => totalBytes == 0 ? 0.0 : (transferredBytes / totalBytes).clamp(0.0, 1.0);

  ShareSessionState copyWith({
    String? sessionId,
    LocalDevice? targetDevice,
    bool? isOutgoing,
    TransferSessionStatus? status,
    Map<String, FileTransferProgress>? files,
    String? errorMessage,
    DateTime? startTime,
  }) {
    return ShareSessionState(
      sessionId: sessionId ?? this.sessionId,
      targetDevice: targetDevice ?? this.targetDevice,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      status: status ?? this.status,
      files: files ?? this.files,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
    );
  }

  @override
  List<Object?> get props => [sessionId, targetDevice, isOutgoing, status, files, errorMessage, startTime];
}
