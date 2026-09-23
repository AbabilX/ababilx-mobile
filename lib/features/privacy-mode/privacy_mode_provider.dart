import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../auth/providers/auth_provider.dart';

/// This account's privacy-mode switch (server migration 0152).
///
/// On: DM peers stop seeing this account typing, its read and delivered
/// ticks, its online state and "Ringing…" on a call to it; a connected call
/// leaves no row on their side; their phone blocks screenshots of the chat
/// and the call; and photos sent here pass through the timer / saving sheet.
/// It is one-way — this phone still sees all of theirs.
///
/// Remembered on the device too: a phone that starts offline must still know
/// it is in privacy mode before its first photo goes into the outbox, or that
/// photo would be sent without the timer / saving sheet.
///
/// [state] is the only answer. Every writer — the first load, a toggle, a
/// flip from another device — claims a new [_epoch] before it starts, and an
/// async result lands only if its epoch is still current, so a slow GET or
/// PUT reply can never put back a switch the user has since moved.
class PrivacyModeNotifier extends Notifier<bool> {
  static const _prefsKey = 'privacy_mode_v1';
  static const _resolveTimeout = Duration(seconds: 3);

  /// The first load of this build; [resolve] waits on it, never reads it.
  Future<void>? _loading;
  int _epoch = 0;

  /// Rebuilt on sign-in and sign-out. Signed out, the device copy is
  /// dropped, so the next account to sign in never starts with the previous
  /// one's switch (its badge, or the photo sheet on its first send).
  @override
  bool build() {
    final epoch = _claim();
    if (!ref.watch(isAuthenticatedProvider)) {
      _loading = null;
      _forget();
      return false;
    }
    _loading = _load(epoch);
    return false;
  }

  /// The switch as it stands now. Waits (briefly) for the first load so a
  /// cold start does not answer with the not-yet-loaded default, then reads
  /// [state] — never the load's own result, which is frozen at the moment it
  /// finished and would ignore every toggle made since.
  Future<bool> resolve() async {
    final loading = _loading;
    if (loading != null) {
      try {
        await loading.timeout(_resolveTimeout);
      } catch (_) {}
    }
    return state;
  }

  /// Returns false when the server refused; the switch is put back.
  Future<bool> set(bool enabled) async {
    final previous = state;
    final epoch = _claim();
    state = enabled;
    try {
      final res = await ref
          .read(apiClientProvider)
          .put(ApiConstants.mePrivacyMode, data: {'enabled': enabled});
      await _commit(epoch, _enabled(res.data));
      return true;
    } catch (_) {
      if (_isCurrent(epoch)) state = previous;
      return false;
    }
  }

  /// Another device of this account flipped it (`chat.peer_privacy` about us).
  void applyRemote(bool enabled) => _commit(_claim(), enabled);

  int _claim() => ++_epoch;

  bool _isCurrent(int epoch) => epoch == _epoch;

  Future<void> _load(int epoch) async {
    try {
      final cached = (await SharedPreferences.getInstance()).getBool(_prefsKey);
      if (cached != null && _isCurrent(epoch)) state = cached;
    } catch (_) {}
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConstants.mePrivacyMode);
      await _commit(epoch, _enabled(res.data));
    } catch (_) {}
  }

  /// Applies and remembers [enabled], unless a newer writer has claimed the
  /// switch since [epoch] was taken.
  Future<void> _commit(int epoch, bool enabled) async {
    if (!_isCurrent(epoch)) return;
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isCurrent(epoch)) await prefs.setBool(_prefsKey, enabled);
    } catch (_) {}
  }

  Future<void> _forget() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_prefsKey);
    } catch (_) {}
  }

  static bool _enabled(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map && data['enabled'] == true;
  }
}

final privacyModeProvider = NotifierProvider<PrivacyModeNotifier, bool>(
  PrivacyModeNotifier.new,
);
