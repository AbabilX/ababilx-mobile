part of '../local_server_service.dart';

mixin PrepareUploadHandler {
  Map<String, ShareSessionState> get _activeSessions;
  Map<String, Completer<bool>> get _pendingUserDecisions;
  Map<String, String> get _uploadTokens;
  Function(ShareSessionState)? get onSessionUpdated;
  Function(
    LocalDevice peer,
    List<LocalFileDto> files,
    Completer<bool> decisionCompleter,
  )?
  get onReceiveRequested;

  Future<void> handlePrepareUpload(HttpRequest request) async {
    final bodyString = await utf8.decoder.bind(request).join();
    final Map<String, dynamic> json =
        jsonDecode(bodyString) as Map<String, dynamic>;

    final senderInfoJson = json['info'] as Map<String, dynamic>? ?? {};
    final senderDevice = LocalDevice.fromJson(
      senderInfoJson,
      ip: request.connectionInfo?.remoteAddress.address ?? '',
    );

    final filesMap = json['files'] as Map<String, dynamic>? ?? {};
    final fileDtos = <LocalFileDto>[];
    for (final entry in filesMap.entries) {
      if (entry.value is Map<String, dynamic>) {
        fileDtos.add(
          LocalFileDto.fromJson(entry.value as Map<String, dynamic>),
        );
      }
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final fileProgressMap = <String, FileTransferProgress>{};
    final responseTokens = <String, String>{};

    for (final f in fileDtos) {
      final token = 'token_${f.id}_$sessionId';
      fileProgressMap[f.id] = FileTransferProgress(
        file: f,
        status: FileStatus.queue,
      );
      responseTokens[f.id] = token;
      _uploadTokens['$sessionId:${f.id}'] = token;
    }

    final session = ShareSessionState(
      sessionId: sessionId,
      targetDevice: senderDevice,
      isOutgoing: false,
      status: TransferSessionStatus.waitingForRecipient,
      files: fileProgressMap,
    );

    _activeSessions[sessionId] = session;
    onSessionUpdated?.call(session);

    // Request recipient acceptance
    final decisionCompleter = Completer<bool>();
    _pendingUserDecisions[sessionId] = decisionCompleter;

    if (onReceiveRequested != null) {
      onReceiveRequested!(senderDevice, fileDtos, decisionCompleter);
    } else {
      // Auto-accept if no prompt handler attached
      decisionCompleter.complete(true);
    }

    final accepted = await decisionCompleter.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );

    _pendingUserDecisions.remove(sessionId);

    if (!accepted) {
      final updated = session.copyWith(status: TransferSessionStatus.declined);
      _activeSessions[sessionId] = updated;
      onSessionUpdated?.call(updated);

      request.response.statusCode = HttpStatus.forbidden;
      request.response.write(
        jsonEncode({'message': 'Recipient declined transfer'}),
      );
      await request.response.close();
      return;
    }

    final acceptedSession = session.copyWith(
      status: TransferSessionStatus.receiving,
    );
    _activeSessions[sessionId] = acceptedSession;
    onSessionUpdated?.call(acceptedSession);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({'sessionId': sessionId, 'files': responseTokens}),
    );
    await request.response.close();
  }
}
