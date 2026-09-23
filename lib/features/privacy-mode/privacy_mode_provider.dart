import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

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
class PrivacyModeNotifier extends Notifier<bool> {
  static const _prefsKey = 'privacy_mode_v1';

  Future<bool>? _loading;

  @override
  bool build() {
    _loading = _load();
    return false;
  }

  Future<bool> _load() async {
    try {
      final cached = (await SharedPreferences.getInstance()).getBool(_prefsKey);
      if (cached != null) state = cached;
    } catch (_) {}
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConstants.mePrivacyMode);
      await _store(_enabled(res.data));
    } catch (_) {}
    return state;
  }

  /// The switch as best known: waits (briefly) for the first load instead of
  /// answering with the not-yet-loaded default.
  Future<bool> resolve() async {
    try {
      return await (_loading ?? Future.value(state)).timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      return state;
    }
  }

  /// Returns false when the server refused; the switch is put back.
  Future<bool> set(bool enabled) async {
    final previous = state;
    state = enabled;
    try {
      final res = await ref
          .read(apiClientProvider)
          .put(ApiConstants.mePrivacyMode, data: {'enabled': enabled});
      await _store(_enabled(res.data));
      return true;
    } catch (_) {
      state = previous;
      return false;
    }
  }

  /// Another device of this account flipped it (`chat.peer_privacy` about us).
  void applyRemote(bool enabled) => _store(enabled);

  Future<void> _store(bool enabled) async {
    state = enabled;
    try {
      await (await SharedPreferences.getInstance()).setBool(_prefsKey, enabled);
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
