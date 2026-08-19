import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/authenticated_fetch.dart';
import '../data/session_repository.dart';

/// Signed-in devices, with the writes the list needs.
///
/// Revoking drops the row optimistically — by the time the server answers it
/// has already deleted that device's credentials, so waiting on a reload only
/// makes the list feel slow. A failure reloads from the server instead.
class SessionsNotifier extends AsyncNotifier<List<UserSession>> {
  @override
  Future<List<UserSession>> build() => fetchWhenAuthenticated(
    ref,
    () => ref.read(sessionRepositoryProvider).list(),
  );

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(sessionRepositoryProvider).list(),
    );
  }

  /// Returns the label the server settled on, or null when the call failed.
  Future<String?> rename(String id, String deviceName) async {
    final current = state.valueOrNull;
    if (current == null) return null;
    try {
      final label = await ref
          .read(sessionRepositoryProvider)
          .rename(id, deviceName.trim());
      state = AsyncData([
        for (final s in current) s.id == id ? s.withLabel(label) : s,
      ]);
      return label;
    } catch (_) {
      await refresh();
      return null;
    }
  }

  Future<bool> revoke(String id) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    try {
      await ref.read(sessionRepositoryProvider).revoke(id);
      state = AsyncData([
        for (final s in current)
          if (s.id != id) s,
      ]);
      return true;
    } catch (_) {
      await refresh();
      return false;
    }
  }

  /// Returns how many devices were signed out, or null when the call failed.
  Future<int?> revokeOthers() async {
    final current = state.valueOrNull;
    if (current == null) return null;
    try {
      final revoked = await ref.read(sessionRepositoryProvider).revokeOthers();
      state = AsyncData([
        for (final s in current)
          if (s.current) s,
      ]);
      return revoked;
    } catch (_) {
      await refresh();
      return null;
    }
  }
}

final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, List<UserSession>>(
      SessionsNotifier.new,
    );
