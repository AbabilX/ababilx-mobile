import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How this device's memory of a peer's identity key compares with the one the
/// server is handing out right now.
enum PeerTrust {
  /// Never recorded — a first conversation, or a fresh install.
  firstSeen,

  /// Same key this device saw last time.
  unchanged,

  /// A different key. Either they reinstalled, or somebody swapped it.
  changed,
}

/// Remembers the fingerprint each peer had the last time we looked, so a key
/// substituted later is noticed without anyone re-comparing digits by hand.
///
/// Nobody compares safety numbers twice. A server that swapped a key after the
/// first conversation would otherwise never be caught, which would make the
/// whole feature decorative.
///
/// A fingerprint is public by construction, so this is ordinary
/// SharedPreferences rather than secure storage. It is per-device on purpose:
/// it records what THIS device has seen, and a fresh install has seen nothing
/// and says nothing.
class SafetyNumberStore {
  const SafetyNumberStore();

  static const String _prefix = 'ababilx_peer_fingerprint_v1_';

  String _key(String ownerUserId, String peerUserId) =>
      '$_prefix${ownerUserId}_$peerUserId';

  /// Compares without recording. A change stays reported until the user
  /// acknowledges it, so a warning cannot be swallowed by the next app launch.
  Future<PeerTrust> check(
    String ownerUserId,
    String peerUserId,
    String fingerprint,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(ownerUserId, peerUserId));
    if (stored == null || stored.isEmpty) return PeerTrust.firstSeen;
    return stored == fingerprint ? PeerTrust.unchanged : PeerTrust.changed;
  }

  /// Records a fingerprint as the one this device now expects.
  Future<void> remember(
    String ownerUserId,
    String peerUserId,
    String fingerprint,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(ownerUserId, peerUserId), fingerprint);
  }

  /// Drops every fingerprint during account switch or a full vault reset.
  Future<void> forgetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final doomed = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in doomed) {
      await prefs.remove(key);
    }
  }
}

final safetyNumberStoreProvider = Provider<SafetyNumberStore>(
  (ref) => const SafetyNumberStore(),
);
