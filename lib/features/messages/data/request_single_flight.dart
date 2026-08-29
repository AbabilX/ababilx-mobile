/// Shares one in-flight future per key. The key is removed after success or
/// failure, so retries are never suppressed.
class RequestSingleFlight<T> {
  final Map<String, Future<T>> _inFlight = {};

  Future<T> run(String key, Future<T> Function() work) {
    final running = _inFlight[key];
    if (running != null) return running;

    late final Future<T> request;
    request = (() async {
      try {
        return await work();
      } finally {
        if (identical(_inFlight[key], request)) _inFlight.remove(key);
      }
    })();
    _inFlight[key] = request;
    return request;
  }
}
