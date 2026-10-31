part of 'ws_client.dart';

/// The socket's life outside the foreground.
///
/// The reference app keeps its websocket for two minutes after the app leaves
/// the screen and then lets FCM carry everything (`IncomingMessageObserver`
/// `maxBackgroundTime`). This socket used to stay up for as long as the process
/// lived: a ping every 30 s from here, one every 54 s from the server, and
/// every presence, typing and receipt event for every contact — each one waking
/// the radio of a phone in a pocket. That background drain is what Samsung's
/// "sleeping apps" and the other OEM battery managers punish, and they punish
/// it by cutting the app off from its pushes. Nothing is lost by closing it:
/// the server never skips a push because a socket is open, and resuming
/// reconnects and resyncs.
extension WsClientBackground on WsClient {
  bool get suspended => _suspended;

  /// Closes the socket and stops retrying until [WsClientRevive.kick] or
  /// [WsClient.connect] asks for it again. Listeners hear an ordinary
  /// disconnect, so presence and "connected" state clear as they would for a
  /// dropped link.
  void suspend() {
    if (!_started || _suspended) return;
    final wasConnected = _connected;
    _suspended = true;
    _closed = true;
    _reconnectTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    // `_connecting` is left alone on purpose: a handshake in flight finishes,
    // sees `_closed` and drops its socket — or, if the app came back in the
    // meantime, keeps it — and nothing can start a second one beside it.
    if (wasConnected) _disconnects.add(null);
  }

  /// Sends [payload] on the open socket; false when there is none.
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

  /// Sends [payload], connecting first if needed — which also revives a
  /// suspended socket, since whoever calls this needs it now.
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
}
