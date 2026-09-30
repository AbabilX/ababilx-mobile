import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/call_log_cache.dart';
import '../data/call_log_repository.dart';
import '../data/models/call_log_entry.dart';
import 'call_log_merge.dart';

class CallLogState {
  const CallLogState({
    this.calls = const [],
    this.cursor = '',
    this.loading = false,
    this.loadingMore = false,
    this.loaded = false,
    this.error,
  });

  final List<CallLogEntry> calls;
  final String cursor;
  final bool loading;
  final bool loadingMore;

  /// A first page has come back at least once — separates "still loading" from
  /// "genuinely no calls yet", which need different screens.
  final bool loaded;
  final String? error;

  bool get hasMore => cursor.isNotEmpty;
  bool get isEmpty => loaded && calls.isEmpty;

  CallLogState copyWith({
    List<CallLogEntry>? calls,
    String? cursor,
    bool? loading,
    bool? loadingMore,
    bool? loaded,
    String? error,
    bool clearError = false,
  }) => CallLogState(
    calls: calls ?? this.calls,
    cursor: cursor ?? this.cursor,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    loaded: loaded ?? this.loaded,
    error: clearError ? null : (error ?? this.error),
  );
}

class CallLogNotifier extends Notifier<CallLogState> {
  /// How long a fetched list is trusted with no reason to doubt it. Calls
  /// ending, the app resuming and pull-to-refresh all bypass it.
  static const freshFor = Duration(minutes: 5);

  Future<void>? _inflight;
  DateTime? _fetchedAt;
  bool _stale = true;
  int _session = 0;

  @override
  CallLogState build() {
    final session = ++_session;
    _inflight = null;
    _fetchedAt = null;
    _stale = true;
    // A sign-out drops the list from memory; the next account never sees it.
    if (!ref.watch(isAuthenticatedProvider)) return const CallLogState();
    Future.microtask(() => _restore(session));
    return const CallLogState();
  }

  CallLogRepository get _repo => ref.read(callLogRepositoryProvider);
  CallLogCache get _cache => ref.read(callLogCacheProvider);

  /// The phone's saved first page, drawn before any request. A fetch that
  /// already landed wins; the cache never overwrites it.
  Future<void> _restore(int session) async {
    final page = await _cache.read();
    if (page == null || session != _session || state.loaded) return;
    state = state.copyWith(
      calls: page.calls,
      cursor: page.nextCursor,
      loaded: true,
    );
  }

  /// Something may have changed since the last fetch (a call ended, the app
  /// came back); the next [refreshIfStale] asks the server.
  void markStale() => _stale = true;

  /// The visit rule: at most one request per launch, then only when marked
  /// stale or older than [freshFor].
  Future<void> refreshIfStale() {
    final at = _fetchedAt;
    final fresh =
        !_stale && at != null && DateTime.now().difference(at) < freshFor;
    if (fresh) return Future.value();
    return load(silent: state.calls.isNotEmpty);
  }

  /// First page. Silent refresh keeps the current list on screen (and on
  /// failure keeps it there too) so returning to the tab never flashes empty.
  /// Callers at the same moment share one request.
  Future<void> load({bool silent = false}) {
    return _inflight ??= _load(
      silent: silent,
    ).whenComplete(() => _inflight = null);
  }

  Future<void> _load({required bool silent}) async {
    final session = _session;
    _stale = false;
    state = state.copyWith(loading: !silent, clearError: true);
    try {
      final page = await _repo.page();
      if (session != _session) return;
      final merged = mergeFirstPage(
        current: state.calls,
        currentCursor: state.cursor,
        page: page,
      );
      _fetchedAt = DateTime.now();
      state = state.copyWith(
        calls: merged.calls,
        cursor: merged.cursor,
        loading: false,
        loaded: true,
      );
      unawaited(_cache.write(page));
    } catch (e) {
      if (session != _session) return;
      _stale = true;
      state = state.copyWith(
        loading: false,
        loaded: state.loaded || !silent,
        error: silent && state.calls.isNotEmpty ? null : e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    final session = _session;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.page(before: state.cursor);
      if (session != _session) return;
      final seen = state.calls.map((c) => c.id).toSet();
      state = state.copyWith(
        calls: [
          ...state.calls,
          ...page.calls.where((c) => !seen.contains(c.id)),
        ],
        // An empty page means the end even if the server still hands back a
        // cursor, so stop asking.
        cursor: page.calls.isEmpty ? '' : page.nextCursor,
        loadingMore: false,
      );
    } catch (_) {
      if (session == _session) state = state.copyWith(loadingMore: false);
    }
  }
}

final callLogProvider = NotifierProvider<CallLogNotifier, CallLogState>(
  CallLogNotifier.new,
);
