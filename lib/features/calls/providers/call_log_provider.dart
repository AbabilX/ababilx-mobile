import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/call_log_repository.dart';
import '../data/models/call_log_entry.dart';

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
  @override
  CallLogState build() => const CallLogState();

  CallLogRepository get _repo => ref.read(callLogRepositoryProvider);

  /// First page. Silent refresh keeps the current list on screen (and on
  /// failure keeps it there too) so returning to the tab never flashes empty.
  Future<void> load({bool silent = false}) async {
    if (state.loading) return;
    state = state.copyWith(loading: !silent, clearError: true);
    try {
      final page = await _repo.page();
      state = state.copyWith(
        calls: page.calls,
        cursor: page.nextCursor,
        loading: false,
        loaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        loaded: state.loaded || !silent,
        error: silent && state.calls.isNotEmpty ? null : e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.page(before: state.cursor);
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
      state = state.copyWith(loadingMore: false);
    }
  }
}

final callLogProvider = NotifierProvider<CallLogNotifier, CallLogState>(
  CallLogNotifier.new,
);
