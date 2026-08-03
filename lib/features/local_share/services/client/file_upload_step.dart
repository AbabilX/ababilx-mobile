import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/device_model.dart';
import '../../models/file_dto.dart';
import '../../models/session_state.dart';
import 'session_file_ops.dart';

/// Uploads a single file within an active send session. Rethrows on cancel
/// so the caller's session-level cancel handling takes over; any other
/// failure is captured as a per-file [FileStatus.failed] so one bad file
/// doesn't abort the rest of the batch.
Future<ShareSessionState> uploadFileStep({
  required Dio dio,
  required CancelToken cancelToken,
  required LocalDevice targetDevice,
  required String remoteSessionId,
  required LocalFileDto fileDto,
  required Map<String, dynamic> fileTokens,
  required ShareSessionState sessionState,
  required void Function(ShareSessionState) onProgress,
}) async {
  final token = fileTokens[fileDto.id] as String?;

  String? failReason;
  if (token == null) {
    failReason = 'Recipient did not accept this file';
  } else if (fileDto.filePath == null) {
    failReason = 'File path missing';
  } else if (!await File(fileDto.filePath!).exists()) {
    failReason = 'File no longer exists on device';
  }

  if (failReason != null) {
    final updated = markFileStatus(
      sessionState,
      fileDto.id,
      FileStatus.failed,
      errorMessage: failReason,
    );
    onProgress(updated);
    return updated;
  }

  final file = File(fileDto.filePath!);
  final uploadUrl =
      '${targetDevice.protocol}://${targetDevice.ip}:${targetDevice.port}/api/localsend/v2/upload?sessionId=$remoteSessionId&fileId=${fileDto.id}&token=$token';

  var current = sessionState;
  try {
    final fileLength = await file.length();
    final fileStream = file.openRead();

    await dio.post(
      uploadUrl,
      data: fileStream,
      options: Options(
        headers: {
          Headers.contentLengthHeader: fileLength,
          'Content-Type': 'application/octet-stream',
        },
      ),
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        final updated = current.files[fileDto.id]?.copyWith(
          bytesTransferred: sent,
          status: FileStatus.transferring,
        );
        if (updated != null) {
          current = replaceFileProgress(current, fileDto.id, updated);
          onProgress(current);
        }
      },
    );

    current = markFileStatus(
      current,
      fileDto.id,
      FileStatus.finished,
      bytesTransferred: fileLength,
    );
    onProgress(current);
    return current;
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) rethrow;
    current = markFileStatus(
      current,
      fileDto.id,
      FileStatus.failed,
      errorMessage: e.message ?? 'Upload failed',
    );
    onProgress(current);
    return current;
  }
}
