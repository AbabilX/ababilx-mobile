import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';

class LocalServerService {
  HttpServer? _server;
  bool _isRunning = false;
  int _port = 53317;

  final Map<String, ShareSessionState> _activeSessions = {};
  final Map<String, Completer<bool>> _pendingUserDecisions = {};

  // Handlers for session changes
  Function(ShareSessionState)? onSessionUpdated;
  Function(LocalDevice peer, List<LocalFileDto> files, Completer<bool> decisionCompleter)? onReceiveRequested;

  bool get isRunning => _isRunning;
  int get port => _port;

  /// Starts the local HTTP server.
  Future<int> startServer({
    required LocalDevice currentDevice,
    int initialPort = 53317,
  }) async {
    if (_isRunning) return _port;

    int bindPort = initialPort;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, bindPort);
    } catch (_) {
      // Fallback to random available port if 53317 is occupied
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }

    _port = _server!.port;
    _isRunning = true;

    _server!.listen((HttpRequest request) {
      _handleRequest(request, currentDevice.copyWith(port: _port));
    });

    return _port;
  }

  void _handleRequest(HttpRequest request, LocalDevice currentDevice) async {
    final path = request.uri.path;
    final method = request.method;

    // CORS & Content-Type headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      if (method == 'GET' && (path == '/api/localsend/v2/info' || path == '/api/localsend/v1/info')) {
        _handleGetInfo(request, currentDevice);
      } else if (method == 'POST' && (path == '/api/localsend/v2/register' || path == '/api/localsend/v1/register')) {
        _handleRegister(request);
      } else if (method == 'POST' && path == '/api/localsend/v2/prepare-upload') {
        await _handlePrepareUpload(request);
      } else if (method == 'POST' && path == '/api/localsend/v2/upload') {
        await _handleUpload(request);
      } else if (method == 'POST' && path == '/api/localsend/v2/cancel') {
        _handleCancel(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'message': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  void _handleGetInfo(HttpRequest request, LocalDevice currentDevice) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(currentDevice.toJson()));
    await request.response.close();
  }

  void _handleRegister(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
  }

  Future<void> _handlePrepareUpload(HttpRequest request) async {
    final bodyString = await utf8.decoder.bind(request).join();
    final Map<String, dynamic> json = jsonDecode(bodyString) as Map<String, dynamic>;

    final senderInfoJson = json['info'] as Map<String, dynamic>? ?? {};
    final senderDevice = LocalDevice.fromJson(senderInfoJson, ip: request.connectionInfo?.remoteAddress.address ?? '');

    final filesMap = json['files'] as Map<String, dynamic>? ?? {};
    final fileDtos = <LocalFileDto>[];
    for (final entry in filesMap.entries) {
      if (entry.value is Map<String, dynamic>) {
        fileDtos.add(LocalFileDto.fromJson(entry.value as Map<String, dynamic>));
      }
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final fileProgressMap = <String, FileTransferProgress>{};
    final responseTokens = <String, String>{};

    for (final f in fileDtos) {
      final token = 'token_${f.id}_$sessionId';
      fileProgressMap[f.id] = FileTransferProgress(file: f, status: FileStatus.queue);
      responseTokens[f.id] = token;
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
      request.response.write(jsonEncode({'message': 'Recipient declined transfer'}));
      await request.response.close();
      return;
    }

    final acceptedSession = session.copyWith(status: TransferSessionStatus.receiving);
    _activeSessions[sessionId] = acceptedSession;
    onSessionUpdated?.call(acceptedSession);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'sessionId': sessionId,
      'files': responseTokens,
    }));
    await request.response.close();
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    final fileId = request.uri.queryParameters['fileId'];

    if (sessionId == null || fileId == null || !_activeSessions.containsKey(sessionId)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final session = _activeSessions[sessionId]!;
    final fileProgress = session.files[fileId];

    if (fileProgress == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    // Security: Sanitize target file name to prevent path traversal
    final rawFileName = fileProgress.file.fileName;
    final sanitizedFileName = p.basename(rawFileName);

    final saveDir = await getApplicationDocumentsDirectory();
    final savePath = p.join(saveDir.path, 'AbabilX_Downloads', sanitizedFileName);
    final saveFile = File(savePath);
    await saveFile.parent.create(recursive: true);

    final sink = saveFile.openWrite();
    int receivedBytes = 0;

    try {
      await request.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        // Update progress state
        final updatedFileProgress = fileProgress.copyWith(
          bytesTransferred: receivedBytes,
          status: FileStatus.transferring,
        );

        final updatedFiles = Map<String, FileTransferProgress>.from(session.files);
        updatedFiles[fileId] = updatedFileProgress;

        final updatedSession = session.copyWith(files: updatedFiles);
        _activeSessions[sessionId] = updatedSession;
        onSessionUpdated?.call(updatedSession);
      }).asFuture();

      await sink.flush();
      await sink.close();

      final finishedFileProgress = fileProgress.copyWith(
        bytesTransferred: receivedBytes,
        status: FileStatus.finished,
      );

      final updatedFiles = Map<String, FileTransferProgress>.from(session.files);
      updatedFiles[fileId] = finishedFileProgress;

      final isAllFinished = updatedFiles.values.every((f) => f.status == FileStatus.finished);
      final finalSession = session.copyWith(
        files: updatedFiles,
        status: isAllFinished ? TransferSessionStatus.finished : TransferSessionStatus.receiving,
      );

      _activeSessions[sessionId] = finalSession;
      onSessionUpdated?.call(finalSession);

      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } catch (e) {
      await sink.close();
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  void _handleCancel(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    if (sessionId != null && _activeSessions.containsKey(sessionId)) {
      final session = _activeSessions[sessionId]!;
      final canceledSession = session.copyWith(status: TransferSessionStatus.canceled);
      _activeSessions[sessionId] = canceledSession;
      onSessionUpdated?.call(canceledSession);
    }
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
  }

  /// Stop local server.
  Future<void> stopServer() async {
    _isRunning = false;
    await _server?.close(force: true);
    _server = null;
    _activeSessions.clear();
    _pendingUserDecisions.clear();
  }
}
