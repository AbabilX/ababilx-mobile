import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'api_client.dart';

part 'ws_client_background.dart';
part 'ws_client_revive.dart';

typedef WsEventHandler = void Function(Map<String, dynamic> event);
typedef WsReconnectHandler = void Function();
typedef WsEnsureAuth = Future<bool> Function();

/// WebSocket client mirroring web `ws-client.ts`.
class WsClient {
  WsClient(this._storage, {this._ensureAuth});

  final SecureStorage _storage;
  final WsEnsureAuth? _ensureAuth;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _connecting = false;

  /// Whether anything has ever asked for this socket. [WsClientRevive.kick]
  /// revives an existing intent and must never invent one: a signed-out app
  /// that gets kicked would start a retry loop against an endpoint it has no
  /// token for.
  bool _started = false;

  /// Closed on purpose because the app has been in the background a while —
  /// see [WsClientBackground.suspend]. [connect] and [WsClientRevive.kick]
  /// clear it; nothing else may reconnect a suspended socket.
  bool _suspended = false;
  bool _connected = false;
  int _backoffMs = 1000;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  final _disconnects = StreamController<void>.broadcast();

  static const _minBackoffMs = 1000;
  static const _maxBackoffMs = 30000;

  /// Signal's keepalive, expressed as one property.
  ///
  /// `dart:io` pings on this interval and closes the socket when the pong does
  /// not come back inside it, which is the only thing that turns a radio that
  /// died under us into an `onDone` this client can reconnect from. Signal
  /// sends its own every 30s under a read timeout ten seconds longer
  /// (`OkHttpWebSocketConnection.KEEPALIVE_FREQUENCY_SECONDS`).
  static const _pingInterval = Duration(seconds: 30);
  static const _connectTimeout = Duration(seconds: 15);

  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<void> get reconnects => _reconnects.stream;
  Stream<void> get disconnects => _disconnects.stream;
  bool get connected => _connected;

  /// Resolves once this attempt — or the one already running — is over.
  ///
  /// It used to return at once while another caller's handshake was still in
  /// flight, so "await connect(), then expect the socket" held only for
  /// whoever happened to start it. Answering a call relies on that: the
  /// caller's offer is relayed to this socket, so it has to be up first.
  Future<void> connect() {
    _closed = false;
    _suspended = false;
    _started = true;
    if (_connected) return Future<void>.value();
    return _inFlight ?? _connectOnce();
  }

  void disconnect() {
    _closed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  /// The handshake in progress, for [connect] to share.
  Future<void>? _inFlight;

  Future<void> _connectOnce({bool retriedAuth = false}) {
    if (_closed || _connected) return Future<void>.value();
    final running = _inFlight;
    if (running != null || _connecting) return running ?? Future<void>.value();
    final attempt = _attempt(retriedAuth: retriedAuth);
    _inFlight = attempt;
    attempt.whenComplete(() {
      if (identical(_inFlight, attempt)) _inFlight = null;
    }).ignore();
    return attempt;
  }

  Future<void> _attempt({required bool retriedAuth}) async {
    if (_closed || _connecting || _connected) return;
    _connecting = true;

    String? token;
    try {
      token = await _storage.readJwt();
    } catch (_) {
      // Throwing past here would leave `_connecting` true for good, and every
      // later connect() and kick() would return without doing anything — no
      // socket, and no calls or chat events, until the app was restarted.
      token = null;
    }
    if (token == null || token.isEmpty) {
      _connecting = false;
      // Stale/missing access token — refresh then retry once.
      if (!retriedAuth && await _refreshAuth()) {
        await _attempt(retriedAuth: true);
        return;
      }
      _scheduleReconnect();
      return;
    }

    await _subscription?.cancel();
    _channel?.sink.close();

    try {
      final channel = IOWebSocketChannel.connect(
        Uri.parse(ApiConstants.notificationsWsUrl),
        protocols: [ApiConstants.wsAuthSubprotocol, token],
        pingInterval: _pingInterval,
        connectTimeout: _connectTimeout,
      );
      _channel = channel;
      await channel.ready;
      if (_closed) {
        // Suspended or signed out mid-handshake: nobody wants this socket.
        _connecting = false;
        _channel = null;
        await channel.sink.close();
        return;
      }
      _connected = true;
      _connecting = false;

      _subscription = channel.stream.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw as String);
            if (decoded is Map<String, dynamic>) {
              _events.add(decoded);
            }
          } catch (_) {}
        },
        onDone: _handleDisconnected,
        onError: (_) => _handleDisconnected(),
        cancelOnError: true,
      );

      _backoffMs = _minBackoffMs;
      _reconnects.add(null);
    } catch (_) {
      _connecting = false;
      _connected = false;
      // 401 / upgrade failure often means expired JWT — refresh once, then retry.
      if (!retriedAuth && await _refreshAuth() && !_closed) {
        await _attempt(retriedAuth: true);
        return;
      }
      _scheduleReconnect();
    }
  }

  /// A refresh that throws counts as a failed one: the retry loop has to keep
  /// going either way, or the socket stays down until the app restarts.
  Future<bool> _refreshAuth() async {
    final ensureAuth = _ensureAuth;
    if (ensureAuth == null) return false;
    try {
      return await ensureAuth();
    } catch (_) {
      return false;
    }
  }

  void _handleDisconnected() {
    final wasConnected = _connected;
    _connected = false;
    _connecting = false;
    _channel = null;
    if (wasConnected) _disconnects.add(null);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), () {
      _backoffMs = (_backoffMs * 2).clamp(_minBackoffMs, _maxBackoffMs);
      _connectOnce();
    });
  }

  Future<void> dispose() async {
    disconnect();
    await _events.close();
    await _reconnects.close();
    await _disconnects.close();
  }
}

final wsClientProvider = Provider<WsClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final api = ref.watch(apiClientProvider);
  final client = WsClient(storage, ensureAuth: api.ensureFreshAccessToken);
  ref.onDispose(client.dispose);
  return client;
});
