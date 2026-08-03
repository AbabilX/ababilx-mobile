import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/received_files_store.dart';
import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';

part 'server/prepare_upload_handler.dart';
part 'server/upload_handler.dart';

class LocalServerService with PrepareUploadHandler, UploadHandler {
  HttpServer? _server;
  bool _isRunning = false;
  int _port = 12045;

  @override
  final Map<String, ShareSessionState> _activeSessions = {};
  @override
  final Map<String, Completer<bool>> _pendingUserDecisions = {};
  // '$sessionId:$fileId' -> minted upload token, so /upload can reject a
  // request that guessed/observed a session id without the matching token.
  @override
  final Map<String, String> _uploadTokens = {};

  // Handlers for session changes
  @override
  Function(ShareSessionState)? onSessionUpdated;
  @override
  Function(
    LocalDevice peer,
    List<LocalFileDto> files,
    Completer<bool> decisionCompleter,
  )?
  onReceiveRequested;

  bool get isRunning => _isRunning;
  int get port => _port;

  /// Starts the local HTTP server.
  Future<int> startServer({
    required LocalDevice currentDevice,
    int initialPort = 12045,
  }) async {
    if (_isRunning) return _port;

    int bindPort = initialPort;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, bindPort);
    } catch (_) {
      // Fallback to random available port if 12045 is occupied
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
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      if (method == 'GET' &&
          (path == '/api/localsend/v2/info' ||
              path == '/api/localsend/v1/info')) {
        _handleGetInfo(request, currentDevice);
      } else if (method == 'POST' &&
          (path == '/api/localsend/v2/register' ||
              path == '/api/localsend/v1/register')) {
        _handleRegister(request);
      } else if (method == 'POST' &&
          path == '/api/localsend/v2/prepare-upload') {
        await handlePrepareUpload(request);
      } else if (method == 'POST' && path == '/api/localsend/v2/upload') {
        await handleUpload(request);
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

  void _handleCancel(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    if (sessionId != null && _activeSessions.containsKey(sessionId)) {
      final session = _activeSessions[sessionId]!;
      final canceledSession = session.copyWith(
        status: TransferSessionStatus.canceled,
      );
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
    _uploadTokens.clear();
  }
}
