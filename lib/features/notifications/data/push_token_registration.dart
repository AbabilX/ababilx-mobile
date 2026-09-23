import 'dart:async';

/// Retries registration independently of notification permission. Only one
/// write is allowed in flight, including when Firebase rotates the token.
class PushTokenRegistration {
  PushTokenRegistration({
    required this.loadToken,
    required this.saveToken,
    required this.registerToken,
    required this.onFailure,
  });

  final Future<String?> Function() loadToken;
  final Future<void> Function(String) saveToken;
  final Future<void> Function(String) registerToken;
  final void Function(Object) onFailure;

  bool _active = false;
  bool _pending = false;
  int _revision = 0;
  int _failures = 0;
  String? _refreshedToken;
  Timer? _retry;
  Future<void>? _inFlight;

  Future<void> start() {
    if (!_active) {
      _active = true;
      _pending = true;
      _revision++;
    }
    return retryPending();
  }

  Future<void> tokenChanged(String token) {
    if (!_active) return Future.value();
    _refreshedToken = token;
    _pending = true;
    _revision++;
    _failures = 0;
    return retryPending();
  }

  /// Called on resume/network recovery; healthy registrations do no work.
  Future<void> retryPending() {
    if (!_active || !_pending) return Future.value();
    _retry?.cancel();
    _retry = null;
    return _inFlight ??= _drain().whenComplete(() => _inFlight = null);
  }

  Future<void> _drain() async {
    while (_active && _pending) {
      final revision = _revision;
      bool current() => _active && revision == _revision;
      try {
        final token = _refreshedToken ?? await loadToken();
        if (!current()) continue;
        if (token == null || token.isEmpty) {
          throw StateError('FCM token unavailable');
        }
        // Save before registering so logout can remove even a registration
        // whose successful server response was lost on the network.
        await saveToken(token);
        if (!current()) continue;
        await registerToken(token);
        if (!current()) continue;
        _pending = false;
        _refreshedToken = null;
        _failures = 0;
      } catch (error) {
        if (!current()) continue;
        onFailure(error);
        // 5, 10, 20, 40, 80, 160, then 300 seconds. No tight retry loop
        // when the API or Play Services is unavailable.
        final seconds = _failures < 6 ? 5 * (1 << _failures) : 300;
        if (_failures < 6) _failures++;
        _retry = Timer(Duration(seconds: seconds), () {
          unawaited(retryPending());
        });
        return;
      }
    }
  }

  /// Stop synchronously, then wait before deregistration so a late successful
  /// POST cannot recreate the token after logout's DELETE.
  Future<void> stop() {
    _active = false;
    _pending = false;
    _revision++;
    _refreshedToken = null;
    _failures = 0;
    _retry?.cancel();
    _retry = null;
    return _inFlight ?? Future.value();
  }
}
