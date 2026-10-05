import 'dart:async';
import 'dart:io';

import '../../services/local_ip_service.dart' show isPrivateIpv4;
import '../protocol/share_ids.dart';
import '../protocol/share_peer.dart';
import '../protocol/share_routes.dart';
import '../store/share_records.dart';
import 'file_handler.dart';
import 'message_handler.dart';
import 'pair_handler.dart';
import 'share_http.dart';
import 'share_server_context.dart';

/// The receive side of `abx-share/1`.
class ShareServer {
  ShareServer(this.context, {this.allowLoopback = false});

  final ShareServerContext context;

  /// Tests talk to it over 127.0.0.1; the app never sets this.
  final bool allowLoopback;

  HttpServer? _server;

  bool get running => _server != null;
  int get port => _server?.port ?? 0;

  /// Binds [preferredPort], or any free port when it is taken, and returns
  /// the one really bound — discovery has to advertise that one.
  Future<int> start({int preferredPort = shareDefaultPort}) async {
    final running = _server;
    if (running != null) return running.port;
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    // A body may take as long as the file is big; idleness is what ends it.
    server.idleTimeout = const Duration(seconds: 60);
    _server = server;
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object _) {},
    );
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    context.pendingPairs.clear();
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (!_allowed(request)) {
        return await replyShareError(request, HttpStatus.forbidden, 'refused');
      }
      await _route(request);
    } catch (_) {
      await replyShareError(request, HttpStatus.internalServerError, 'error');
    }
  }

  /// A web page (it sends `Origin`) and anything from outside the local
  /// network are refused before a route is looked at.
  bool _allowed(HttpRequest request) {
    if (request.headers.value('origin') != null) return false;
    final address = request.connectionInfo?.remoteAddress;
    if (address == null) return false;
    if (address.isLoopback) return allowLoopback;
    return isPrivateIpv4(address.address);
  }

  Future<void> _route(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;
    if (method == 'GET' && path == ShareRoutes.info) {
      return replyShare(
        request,
        HttpStatus.ok,
        context.self().toJson(announce: false),
      );
    }
    if (method == 'POST' && path == ShareRoutes.pair) {
      return handleSharePair(context, request);
    }

    final device = await _authenticate(request);
    if (device == null) {
      return replyShareError(request, HttpStatus.unauthorized, 'unpaired');
    }
    if (method == 'POST' && path == ShareRoutes.messages) {
      return handleShareMessage(context, request, device);
    }
    final segments = request.uri.pathSegments;
    if (method == 'PUT' &&
        segments.length == 5 &&
        path.startsWith(ShareRoutes.filesPrefix) &&
        isShareId(segments[3]) &&
        isShareId(segments[4])) {
      return handleShareFile(
        context,
        request,
        device,
        segments[3],
        segments[4],
      );
    }
    if (method == 'POST' &&
        segments.length == 5 &&
        path.startsWith('${ShareRoutes.messages}/') &&
        segments[4] == 'cancel' &&
        isShareId(segments[3])) {
      return handleShareCancel(context, request, device, segments[3]);
    }
    await replyShareError(request, HttpStatus.notFound, 'not_found');
  }

  Future<ShareDeviceRecord?> _authenticate(HttpRequest request) async {
    final id = request.headers.value(ShareRoutes.deviceHeader);
    final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!isShareId(id) || !auth.startsWith('Bearer ')) return null;
    final device = await context.store.device(id!);
    final token = device?.pairToken;
    if (device == null || device.blocked || token == null) return null;
    return sameSecret(token, auth.substring(7)) ? device : null;
  }
}
