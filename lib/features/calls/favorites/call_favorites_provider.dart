import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import 'call_favorite.dart';

/// The Talks tab's favourites — device-local, no server, like the wallpaper.
///
/// Kept per ACCOUNT (`call_favorites_v1:<user id>`), never in one shared key:
/// a second account on this phone must not see the first one's people, and
/// the same account signing back in gets its list back. The owner is the
/// local-data owner in secure storage, readable offline.
class CallFavoritesNotifier extends Notifier<List<CallFavorite>> {
  static const _prefix = 'call_favorites_v1:';

  /// Kept short on purpose: a long strip is a second contact list, and
  /// nobody scrolls sideways to find someone fast.
  static const maxFavorites = 12;

  String _owner = '';
  int _session = 0;
  Future<void>? _loading;

  @override
  List<CallFavorite> build() {
    final session = ++_session;
    _owner = '';
    if (!ref.watch(isAuthenticatedProvider)) {
      _loading = null;
      return const [];
    }
    _loading = _load(session);
    return const [];
  }

  bool contains(String conversationId) =>
      state.any((f) => f.conversationId == conversationId);

  /// False when the list is already full. Adding one already there refreshes
  /// its name and picture in place.
  Future<bool> add(CallFavorite favorite) async {
    // An edit made before the stored list arrived would be overwritten by it.
    await _loading;
    final index = state.indexWhere(
      (f) => f.conversationId == favorite.conversationId,
    );
    if (index >= 0) {
      state = [...state]..[index] = favorite;
    } else {
      if (state.length >= maxFavorites) return false;
      state = [...state, favorite];
    }
    await _save();
    return true;
  }

  /// Moves a favourite to a new place in the strip.
  Future<void> move(int from, int to) async {
    await _loading;
    if (from == to || from < 0 || to < 0) return;
    if (from >= state.length || to >= state.length) return;
    final next = [...state];
    next.insert(to, next.removeAt(from));
    state = next;
    await _save();
  }

  Future<void> remove(String conversationId) async {
    await _loading;
    state = state.where((f) => f.conversationId != conversationId).toList();
    await _save();
  }

  Future<void> _load(int session) async {
    try {
      final owner =
          (await ref.read(secureStorageProvider).readLocalDataOwnerUserId())
              ?.trim() ??
          '';
      if (owner.isEmpty || session != _session) return;
      final raw = (await SharedPreferences.getInstance()).getString(
        '$_prefix$owner',
      );
      if (session != _session) return;
      _owner = owner;
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      state = list
          .map(CallFavorite.fromJson)
          .whereType<CallFavorite>()
          .toList();
    } catch (_) {
      // A broken entry reads as no favourites, never as a broken tab.
    }
  }

  Future<void> _save() async {
    if (_owner.isEmpty) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
        '$_prefix$_owner',
        jsonEncode(state.map((f) => f.toJson()).toList()),
      );
    } catch (_) {}
  }
}

final callFavoritesProvider =
    NotifierProvider<CallFavoritesNotifier, List<CallFavorite>>(
      CallFavoritesNotifier.new,
    );
