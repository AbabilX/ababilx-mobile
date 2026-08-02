import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';

class LocalTransferClientService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 10),
  ));

  final Map<String, CancelToken> _activeCancelTokens = {};

  /// Initiates sending files to a target peer device.
  Future<ShareSessionState> sendFiles({
    required LocalDevice targetDevice,
    required LocalDevice currentDevice,
    required List<LocalFileDto> files,
    required Function(ShareSessionState) onProgress,
  }) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final cancelToken = CancelToken();
    _activeCancelTokens[sessionId] = cancelToken;

    final fileProgressMap = <String, FileTransferProgress>{
      for (final f in files)
        f.id: FileTransferProgress(file: f, status: FileStatus.queue)
    };

    var sessionState = ShareSessionState(
      sessionId: sessionId,
      targetDevice: targetDevice,
      isOutgoing: true,
      status: TransferSessionStatus.waitingForRecipient,
      files: fileProgressMap,
    );
    onProgress(sessionState);

    try {
      final prepareUrl = '${targetDevice.protocol}://${targetDevice.ip}:${targetDevice.port}/api/localsend/v2/prepare-upload';

      final preparePayload = {
        'info': currentDevice.toJson(),
        'files': {
          for (final f in files) f.id: f.toJson()
        },
      };

      final response = await _dio.post(
        prepareUrl,
        data: preparePayload,
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
        sessionState = sessionState.copyWith(
          status: TransferSessionStatus.declined,
          errorMessage: 'Recipient declined file transfer',
        );
        onProgress(sessionState);
        return sessionState;
      }

      final json = response.data as Map<String, dynamic>;
      final remoteSessionId = json['sessionId'] as String? ?? sessionId;
      final fileTokens = json['files'] as Map<String, dynamic>? ?? {};

      sessionState = sessionState.copyWith(status: TransferSessionStatus.sending);
      onProgress(sessionState);

      // Upload each file stream sequentially
      for (final fileDto in files) {
        final token = fileTokens[fileDto.id] as String?;
        if (token == null || fileDto.filePath == null) continue;

        final file = File(fileDto.filePath!);
        if (!await file.exists()) continue;

        final uploadUrl = '${targetDevice.protocol}://${targetDevice.ip}:${targetDevice.port}/api/localsend/v2/upload?sessionId=$remoteSessionId&fileId=${fileDto.id}&token=$token';

        final fileLength = await file.length();
        final fileStream = file.openRead();

        await _dio.post(
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
            final updatedFileProgress = sessionState.files[fileDto.id]?.copyWith(
              bytesTransferred: sent,
              status: FileStatus.transferring,
            );

            if (updatedFileProgress != null) {
              final updatedFiles = Map<String, FileTransferProgress>.from(sessionState.files);
              updatedFiles[fileDto.id] = updatedFileProgress;
              sessionState = sessionState.copyWith(files: updatedFiles);
              onProgress(sessionState);
            }
          },
        );

        final finishedFileProgress = sessionState.files[fileDto.id]?.copyWith(
          bytesTransferred: fileLength,
          status: FileStatus.finished,
        );

        if (finishedFileProgress != null) {
          final updatedFiles = Map<String, FileTransferProgress>.from(sessionState.files);
          updatedFiles[fileDto.id] = finishedFileProgress;
          sessionState = sessionState.copyWith(files: updatedFiles);
          onProgress(sessionState);
        }
      }

      sessionState = sessionState.copyWith(status: TransferSessionStatus.finished);
      onProgress(sessionState);
      return sessionState;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        sessionState = sessionState.copyWith(status: TransferSessionStatus.canceled);
      } else {
        sessionState = sessionState.copyWith(
          status: TransferSessionStatus.error,
          errorMessage: e.message ?? 'Transfer failed',
        );
      }
      onProgress(sessionState);
      return sessionState;
    } catch (e) {
      sessionState = sessionState.copyWith(
        status: TransferSessionStatus.error,
        errorMessage: e.toString(),
      );
      onProgress(sessionState);
      return sessionState;
    } finally {
      _activeCancelTokens.remove(sessionId);
    }
  }

  /// Cancels an active file upload session.
  Future<void> cancelSession(String sessionId, LocalDevice targetDevice) async {
    _activeCancelTokens[sessionId]?.cancel();
    _activeCancelTokens.remove(sessionId);

    try {
      final cancelUrl = '${targetDevice.protocol}://${targetDevice.ip}:${targetDevice.port}/api/localsend/v2/cancel?sessionId=$sessionId';
      await _dio.post(cancelUrl);
    } catch (_) {}
  }
}
