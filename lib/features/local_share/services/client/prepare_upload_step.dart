import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/device_model.dart';
import '../../models/file_dto.dart';
import '../../models/session_state.dart';

/// Result of the prepare-upload handshake: the (possibly updated) session
/// plus the accepted file tokens, or a `null` token map if the session was
/// declined/errored — the caller should stop in that case.
class PreparedUpload {
  const PreparedUpload({
    required this.sessionState,
    required this.remoteSessionId,
    required this.fileTokens,
  });

  final ShareSessionState sessionState;
  final String? remoteSessionId;
  final Map<String, dynamic>? fileTokens;
}

/// Runs the LocalSend v2 `/prepare-upload` handshake against [targetDevice].
Future<PreparedUpload> prepareUploadStep({
  required Dio dio,
  required LocalDevice targetDevice,
  required LocalDevice currentDevice,
  required List<LocalFileDto> files,
  required CancelToken cancelToken,
  required ShareSessionState sessionState,
}) async {
  final prepareUrl =
      '${targetDevice.protocol}://${targetDevice.ip}:${targetDevice.port}/api/localsend/v2/prepare-upload';
  final preparePayload = {
    'info': currentDevice.toJson(),
    'files': {for (final f in files) f.id: f.toJson()},
  };

  Response<dynamic> response;
  try {
    response = await dio.post(
      prepareUrl,
      data: preparePayload,
      cancelToken: cancelToken,
    );
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) rethrow;
    final declined = e.response?.statusCode == HttpStatus.forbidden;
    return PreparedUpload(
      sessionState: sessionState.copyWith(
        status: declined
            ? TransferSessionStatus.declined
            : TransferSessionStatus.error,
        errorMessage: declined
            ? 'Recipient declined file transfer'
            : (e.message ?? 'Could not reach ${targetDevice.alias}'),
      ),
      remoteSessionId: null,
      fileTokens: null,
    );
  }

  if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
    return PreparedUpload(
      sessionState: sessionState.copyWith(
        status: TransferSessionStatus.error,
        errorMessage: 'Unexpected response from ${targetDevice.alias}',
      ),
      remoteSessionId: null,
      fileTokens: null,
    );
  }

  final json = response.data as Map<String, dynamic>;
  return PreparedUpload(
    sessionState: sessionState,
    remoteSessionId: json['sessionId'] as String? ?? sessionState.sessionId,
    fileTokens: json['files'] as Map<String, dynamic>? ?? {},
  );
}
