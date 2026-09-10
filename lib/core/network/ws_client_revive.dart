part of 'ws_client.dart';

/// Waking a socket that died without saying so.
///
/// A TCP connection that goes with the radio — a Wi-Fi to cellular handover, a
/// carrier NAT dropping an idle flow, a frozen app the server gave up writing
/// to — closes nothing on this end. The stream never ends, so `onDone` never
/// fires, `_connected` stays true, and the client sits there believing it is
/// live while every event lands on a socket nobody holds. That is exactly what
/// "I had to pull to refresh" is: HTTP opens a fresh connection and works,
/// while the socket beside it has been dead since the screen went off.
///
/// The keepalive on [WsClient] catches it on its own within a minute. These two
/// are for the moments where a minute is a minute too long, and are what
/// Signal's `IncomingMessageObserver` wakes its connect loop for: the app
/// coming to the foreground, and the default network changing underneath it.
extension WsClientRevive on WsClient {
  /// Connects now, without waiting out the backoff.
  ///
  /// Safe to call on a healthy socket — it returns immediately. A failed
  /// attempt may have grown the delay to 30 seconds, and that timer must not be
  /// the only thing between somebody opening the app and their messages.
  Future<void> kick() async {
    if (!_started) return;
    _closed = false;
    if (_connected || _connecting) return;
    _reconnectTimer?.cancel();
    _backoffMs = WsClient._minBackoffMs;
    await _connectOnce();
  }

  /// Throws away a socket that cannot still be alive, because the interface it
  /// was opened on is gone. Nothing will arrive on it and nothing it sends will
  /// leave; closing it here is what produces the reconnect, since the peer has
  /// no route left to tell us it went away.
  void dropSocket() {
    if (_channel == null && !_connected) return;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _handleDisconnected();
  }
}
