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
  int _backoffMs = 1000;

  static const _minBackoffMs = 1000;
  static const _maxBackoffMs = 30000;

  WsEventHandler? onEvent;
  WsReconnectHandler? onReconnect;

  Future<void> connect() async {
    _closed = false;
    await _connectOnce();
  }

  void disconnect() {
    _closed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  bool send(Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null) return false;
    try {
      ch.sink.add(jsonEncode(payload));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _connectOnce() async {
    if (_closed) return;

    final token = await _storage.readJwt();
    if (token == null || token.isEmpty) return;

    await _subscription?.cancel();
    _channel?.sink.close();

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(ApiConstants.notificationsWsUrl),
        protocols: [ApiConstants.wsAuthSubprotocol, token],
      );
      _channel = channel;

      _subscription = channel.stream.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw as String);
            if (decoded is Map<String, dynamic>) {
              onEvent?.call(decoded);
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );

      _backoffMs = _minBackoffMs;
      onReconnect?.call();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), () {
      _backoffMs = (_backoffMs * 2).clamp(_minBackoffMs, _maxBackoffMs);
      _connectOnce();
    });
  }
}

final wsClientProvider = Provider<WsClient>((ref) {
  final client = WsClient(ref.watch(secureStorageProvider));
  ref.onDispose(client.disconnect);
  return client;
});
