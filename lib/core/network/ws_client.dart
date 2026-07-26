import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'api_client.dart';

typedef WsEventHandler = void Function(Map<String, dynamic> event);
typedef WsReconnectHandler = void Function();

/// WebSocket client mirroring web `ws-client.ts`.
class WsClient {
  WsClient(this._storage);

  final SecureStorage _storage;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _connecting = false;
  bool _connected = false;
  int _backoffMs = 1000;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  final _disconnects = StreamController<void>.broadcast();

  static const _minBackoffMs = 1000;
  static const _maxBackoffMs = 30000;

  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<void> get reconnects => _reconnects.stream;
  Stream<void> get disconnects => _disconnects.stream;
  bool get connected => _connected;

  Future<void> connect() async {
    _closed = false;
    if (_connected || _connecting) return;
    await _connectOnce();
  }

  void disconnect() {
    _closed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  bool send(Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null || !_connected) return false;
    try {
      ch.sink.add(jsonEncode(payload));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendWhenConnected(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (send(payload)) return true;
    final ready = reconnects.first;
    await connect();
    if (send(payload)) return true;
    try {
      await ready.timeout(timeout);
    } catch (_) {
      return false;
    }
    return send(payload);
  }

  Future<void> _connectOnce() async {
    if (_closed || _connecting || _connected) return;
    _connecting = true;

    final token = await _storage.readJwt();
    if (token == null || token.isEmpty) {
      _connecting = false;
      return;
    }

    await _subscription?.cancel();
    _channel?.sink.close();

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(ApiConstants.notificationsWsUrl),
        protocols: [ApiConstants.wsAuthSubprotocol, token],
      );
      _channel = channel;
      await channel.ready;
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
      _scheduleReconnect();
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
  final client = WsClient(ref.watch(secureStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});
