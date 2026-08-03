part of '../local_server_service.dart';

mixin UploadHandler {
  Map<String, ShareSessionState> get _activeSessions;
  Map<String, String> get _uploadTokens;
  Function(ShareSessionState)? get onSessionUpdated;

  Future<void> handleUpload(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    final fileId = request.uri.queryParameters['fileId'];
    final token = request.uri.queryParameters['token'];

    if (sessionId == null ||
        fileId == null ||
        !_activeSessions.containsKey(sessionId)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final session = _activeSessions[sessionId]!;

    if (session.status == TransferSessionStatus.declined ||
        session.status == TransferSessionStatus.canceled) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    final fileProgress = session.files[fileId];
    if (fileProgress == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final expectedToken = _uploadTokens['$sessionId:$fileId'];
    if (expectedToken == null || token != expectedToken) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    // Security: sanitize target file name to prevent path traversal.
    final rawFileName = fileProgress.file.fileName;
    final sanitizedFileName = p.basename(rawFileName);
    if (sanitizedFileName.isEmpty ||
        sanitizedFileName == '.' ||
        sanitizedFileName == '..') {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    // Stream into a private temp file first, then publish to the visible
    // Download/AbabilXStorage location once the transfer completes.
    final tempPath = await ReceivedFilesStore.reserveTempPath(
      sanitizedFileName,
    );
    final tempFile = File(tempPath);
    await tempFile.parent.create(recursive: true);

    final sink = tempFile.openWrite();
    int receivedBytes = 0;

    try {
      await request.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final updatedFileProgress = fileProgress.copyWith(
          bytesTransferred: receivedBytes,
          status: FileStatus.transferring,
        );

        final updatedFiles = Map<String, FileTransferProgress>.from(
          session.files,
        );
        updatedFiles[fileId] = updatedFileProgress;

        final updatedSession = session.copyWith(files: updatedFiles);
        _activeSessions[sessionId] = updatedSession;
        onSessionUpdated?.call(updatedSession);
      }).asFuture();

      await sink.flush();
      await sink.close();

      final savedPath = await ReceivedFilesStore.publish(
        tempPath,
        sanitizedFileName,
      );

      final finishedFileProgress = fileProgress.copyWith(
        file: fileProgress.file.copyWith(filePath: savedPath),
        bytesTransferred: receivedBytes,
        status: FileStatus.finished,
      );

      final updatedFiles = Map<String, FileTransferProgress>.from(
        session.files,
      );
      updatedFiles[fileId] = finishedFileProgress;

      final isAllFinished = updatedFiles.values.every(
        (f) => f.status == FileStatus.finished,
      );
      final finalSession = session.copyWith(
        files: updatedFiles,
        status: isAllFinished
            ? TransferSessionStatus.finished
            : TransferSessionStatus.receiving,
      );

      _activeSessions[sessionId] = finalSession;
      onSessionUpdated?.call(finalSession);

      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final failedFileProgress = fileProgress.copyWith(
        status: FileStatus.failed,
        errorMessage: e.toString(),
      );
      final updatedFiles = Map<String, FileTransferProgress>.from(
        session.files,
      );
      updatedFiles[fileId] = failedFileProgress;
      final failedSession = session.copyWith(
        files: updatedFiles,
        status: TransferSessionStatus.error,
      );
      _activeSessions[sessionId] = failedSession;
      onSessionUpdated?.call(failedSession);

      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }
}
