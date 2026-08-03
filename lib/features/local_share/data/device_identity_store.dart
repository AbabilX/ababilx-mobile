import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _key = 'local_share_fingerprint';

/// Loads this device's persisted LAN fingerprint, minting one on first use.
/// Stable across app restarts so a peer isn't rediscovered as a new device
/// every time it relaunches.
Future<String> loadOrCreateDeviceFingerprint() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_key);
  if (existing != null && existing.isNotEmpty) return existing;

  final fingerprint = 'ababilx_${_randomHex(32)}';
  await prefs.setString(_key, fingerprint);
  return fingerprint;
}

String _randomHex(int length) {
  final rand = Random.secure();
  const chars = '0123456789abcdef';
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}
