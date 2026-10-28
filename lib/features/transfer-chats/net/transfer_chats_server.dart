import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../local_share/services/local_ip_service.dart' show isPrivateIpv4;
import '../wire/transfer_chats_wire.dart';

/// The new device's side of Transfer chats: one HTTP server on the local
/// network, three routes, one sender.
///
/// It decides nothing about what arrives — the stream is sealed under the
/// code's secret and only the importer opens it. Its job is to refuse
/// everybody but the device that read the code (the token), refuse a web
/// page (`Origin`) and anything off the local network, and take exactly one
/// identity and one stream.
class TransferChatsServer {
  TransferChatsServer({
    required this.token,
    required this.onIdentity,
    required this.streamFile,
    required this.onReceived,
    required this.status,
    this.onBytes,
    this.allowLoopback = false,
  });

  final String token;

  /// Opens and adopts the sealed message key. Throws when it does not open.
  final Future<void> Function(Map<String, dynamic> envelope) onIdentity;

  /// Where the stream is written (a fresh file each attempt).
  final Future<File> Function() streamFile;

  /// The whole stream is on disk. Runs after the sender has its answer.
  final Future<void> Function(File file) onReceived;

  final TransferStatus Function() status;
  final void Function(int bytes)? onBytes;

  /// Tests talk to it over 127.0.0.1; the app never sets this.
  final bool allowLoopback;

  static const _maxIdentityBytes = 64 * 1024;

  HttpServer? _server;
  bool _identityTaken = false;
  bool _streaming = false;
  bool _received = false;

  int get port => _server?.port ?? 0;

  Future<int> start() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    // A stream of a few gigabytes is fine; a stalled one is ended.
    server.idleTimeout = const Duration(seconds: 60);
    _server = server;
    server.listen((r) => unawaited(_handle(r)), onError: (Object _) {});
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (!_allowed(request)) {
        return await _reply(request, HttpStatus.forbidden);
      }
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      if (auth == null || !sameTransferToken(auth, 'Bearer $token')) {
        return await _reply(request, HttpStatus.unauthorized);
      }
      final route = '${request.method} ${request.uri.path}';
      switch (route) {
        case 'GET $transferPathStatus':
          return await _reply(request, HttpStatus.ok, status().toJson());
        case 'POST $transferPathIdentity':
          return await _identity(request);
        case 'PUT $transferPathStream':
          return await _stream(request);
      }
      return await _reply(request, HttpStatus.notFound);
    } catch (_) {
      try {
        await _reply(request, HttpStatus.internalServerError);
      } catch (_) {}
    }
  }

  bool _allowed(HttpRequest request) {
    if (request.headers.value('origin') != null) return false;
    final address = request.connectionInfo?.remoteAddress;
    if (address == null) return false;
    if (address.isLoopback) return allowLoopback;
    return isPrivateIpv4(address.address);
  }

  Future<void> _identity(HttpRequest request) async {
    if (_identityTaken) return _reply(request, HttpStatus.conflict);
    final body = BytesBuilder(copy: false);
    await for (final chunk in request) {
      body.add(chunk);
      if (body.length > _maxIdentityBytes) {
        return _reply(request, HttpStatus.requestEntityTooLarge);
      }
    }
    final Map<String, dynamic> envelope;
    try {
      envelope = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(body.takeBytes())) as Map,
      );
      await onIdentity(envelope);
    } catch (_) {
      return _reply(request, HttpStatus.badRequest);
    }
    _identityTaken = true;
    return _reply(request, HttpStatus.ok);
  }

  /// The message key comes first: the history is no use without it, and a
  /// sender that cannot hand it over must not fill this phone first.
  Future<void> _stream(HttpRequest request) async {
    if (!_identityTaken || _streaming || _received) {
      return _reply(request, HttpStatus.conflict);
    }
    _streaming = true;
    File? file;
    IOSink? sink;
    var bytes = 0;
    try {
      file = await streamFile();
      sink = file.openWrite();
      // addStream pauses the request while the disk catches up, so a LAN
      // faster than this phone's flash never piles up in memory.
      await sink.addStream(
        request.map((chunk) {
          bytes += chunk.length;
          onBytes?.call(bytes);
          return chunk;
        }),
      );
      await sink.flush();
      await sink.close();
    } catch (_) {
      // The sender went away mid-stream, or the file could not be written.
      // It may try again from the start.
      await sink?.close().catchError((_) {});
      await file?.delete().catchError((_) => file!);
      _streaming = false;
      return;
    }
    _received = true;
    _streaming = false;
    await _reply(request, HttpStatus.ok);
    unawaited(onReceived(file));
  }

  Future<void> _reply(
    HttpRequest request,
    int code, [
    Map<String, dynamic>? body,
  ]) async {
    final response = request.response..statusCode = code;
    if (body != null) {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
    }
    await response.close();
  }
}
