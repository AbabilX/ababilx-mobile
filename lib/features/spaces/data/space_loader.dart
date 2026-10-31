import 'dart:async';

import 'space_failure.dart';

/// What a Spaces screen draws: the data it has (saved or fresh), whether a
/// request is running, and why the last one failed.
class SpaceLoad<T> {
  const SpaceLoad({this.data, this.loading = false, this.failure});

  final T? data;
  final bool loading;
  final SpaceFailure? failure;

  /// Drawing a saved copy because the network failed.
  bool get showingSaved => data != null && failure != null;

  SpaceLoad<T> copyWith({
    T? data,
    bool? loading,
    SpaceFailure? failure,
    bool clearFailure = false,
  }) => SpaceLoad<T>(
    data: data ?? this.data,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Cache first, then network; every path ends with loading false.
///
/// - the saved copy is drawn before any request;
/// - a failure keeps it and only adds [SpaceLoad.failure];
/// - a request that hangs past [timeout] counts as offline;
/// - a broken cache read or write never turns into an error on screen;
/// - concurrent refreshes share one request; nothing is emitted after
///   [dispose].
class SpaceLoader<T> {
  SpaceLoader({
    required this.readCache,
    required this.writeCache,
    required this.fetch,
    required this.onState,
    this.timeout = const Duration(seconds: 12),
  });

  final Future<T?> Function() readCache;
  final Future<void> Function(T value) writeCache;
  final Future<T> Function() fetch;
  final void Function(SpaceLoad<T> state) onState;
  final Duration timeout;

  SpaceLoad<T> _state = SpaceLoad<T>();
  Future<void>? _inFlight;
  bool _disposed = false;

  SpaceLoad<T> get state => _state;

  void _emit(SpaceLoad<T> s) {
    if (_disposed) return;
    _state = s;
    onState(s);
  }

  /// First load: saved copy, then the network.
  Future<void> load() async {
    if (_inFlight != null) return _inFlight;
    T? saved;
    try {
      saved = await readCache();
    } catch (_) {}
    _emit(SpaceLoad<T>(data: saved ?? _state.data, loading: true));
    return refresh();
  }

  /// Ask the network again (pull to refresh, Retry).
  Future<void> refresh() =>
      _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<void> _run() async {
    _emit(_state.copyWith(loading: true));
    try {
      final fresh = await fetch().timeout(timeout);
      _emit(SpaceLoad<T>(data: fresh));
      try {
        await writeCache(fresh);
      } catch (_) {}
    } on TimeoutException {
      _emit(_state.copyWith(loading: false, failure: SpaceFailure.offline));
    } catch (e) {
      _emit(_state.copyWith(loading: false, failure: classifySpaceError(e)));
    }
  }

  void dispose() => _disposed = true;
}
