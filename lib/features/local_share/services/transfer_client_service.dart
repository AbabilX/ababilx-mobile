import 'dart:async';

import 'package:dio/dio.dart';
import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';
import 'client/file_upload_step.dart';
import 'client/prepare_upload_step.dart';

class LocalTransferClientService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  final Map<String, CancelToken> _activeCancelTokens = {};
  // Local session id -> the id the receiver actually knows it by, so cancel
  // targets the right session on the other end.
  final Map<String, String> _remoteSessionIds = {};

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
        f.id: FileTransferProgress(file: f, status: FileStatus.queue),
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
      final prepared = await prepareUploadStep(
        dio: _dio,
        targetDevice: targetDevice,
        currentDevice: currentDevice,
        files: files,
        cancelToken: cancelToken,
        sessionState: sessionState,
      );
      sessionState = prepared.sessionState;
      if (prepared.fileTokens == null) {
        onProgress(sessionState);
        return sessionState;
      }
      final remoteSessionId = prepared.remoteSessionId!;
      _remoteSessionIds[sessionId] = remoteSessionId;

      sessionState = sessionState.copyWith(
        status: TransferSessionStatus.sending,
      );
      onProgress(sessionState);

      // Upload each file stream sequentially; one file's failure must not
      // abort the rest, and a skipped/failed file must not read as success.
      for (final fileDto in files) {
        sessionState = await uploadFileStep(
          dio: _dio,
          cancelToken: cancelToken,
          targetDevice: targetDevice,
          remoteSessionId: remoteSessionId,
          fileDto: fileDto,
          fileTokens: prepared.fileTokens!,
          sessionState: sessionState,
          onProgress: onProgress,
        );
      }

      final allFinished = sessionState.files.values.every(
        (f) => f.status == FileStatus.finished,
      );
      final failedCount = sessionState.files.values
          .where((f) => f.status == FileStatus.failed)
          .length;
      sessionState = sessionState.copyWith(
        status: allFinished
            ? TransferSessionStatus.finished
            : TransferSessionStatus.error,
        errorMessage: allFinished
            ? null
            : '$failedCount of ${sessionState.files.length} file(s) failed to send',
      );
      onProgress(sessionState);
      return sessionState;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        sessionState = sessionState.copyWith(
          status: TransferSessionStatus.canceled,
        );
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
      _remoteSessionIds.remove(sessionId);
    }
  }

  /// Cancels an active file upload session, notifying the receiver by its
  /// own session id (the sender and receiver mint different ids for the
  /// same transfer).
  Future<void> cancelSession(String sessionId, LocalDevice targetDevice) async {
    _activeCancelTokens[sessionId]?.cancel();
    _activeCancelTokens.remove(sessionId);

    final remoteSessionId = _remoteSessionIds.remove(sessionId) ?? sessionId;
    try {
      final cancelUrl =
          '${targetDevice.protocol}://${targetDevice.ip}:${targetDevice.port}/api/localsend/v2/cancel?sessionId=$remoteSessionId';
      await _dio.post(cancelUrl);
    } catch (_) {}
  }
}
