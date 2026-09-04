import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'push_latency_sample.dart';

/// The rolling record of how late this phone's pushes have been.
///
/// Written from the FCM background isolate and read by the app, so
/// [SharedPreferencesAsync] is deliberate for the same reason as
/// `ChatNotificationStore`: it reads through to the platform instead of caching,
/// and one isolate always sees what the other wrote.
///
/// Only background pushes are recorded. A push that lands while the app is open
/// is fast by construction — nothing is dozing — so counting those would
/// dilute the percentiles with the exact population that can never be slow.
class PushLatencyStore {
  const PushLatencyStore._();

  static const _key = 'notif_push_latency_v1';

  /// Enough to satisfy the heuristic's sample floor several times over, small
  /// enough that the JSON stays a few KB.
  static const _maxSamples = 200;

  /// Older than this and the phone may be a different phone, in a different
  /// place, on a different ROM.
  static const _retention = Duration(days: 7);

  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  /// [sentAt] is FCM's own `RemoteMessage.sentTime`.
  static Future<void> record(DateTime sentAt, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    // A phone whose clock is behind the sender's reports a negative gap. That
    // is a clock, not a delay, so it counts as instant rather than as evidence.
    final latency = now.isBefore(sentAt)
        ? Duration.zero
        : now.difference(sentAt);
    try {
      final samples = List<PushLatencySample>.from(await read(at: now))
        ..add(PushLatencySample(receivedAt: now, latency: latency));
      await _write(samples);
    } catch (_) {
      // Losing a sample costs the heuristic nothing it will notice.
    }
  }

  /// Samples still inside the retention window, oldest first.
  static Future<List<PushLatencySample>> read({DateTime? at}) async {
    final cutoff = (at ?? DateTime.now()).subtract(_retention);
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PushLatencySample.fromJson)
          .where((sample) => sample.receivedAt.isAfter(cutoff))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Called once the user acts on the prompt: the old evidence describes a
  /// phone configured the way it no longer is.
  static Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {}
  }

  static Future<void> _write(List<PushLatencySample> samples) async {
    final trimmed = samples.length <= _maxSamples
        ? samples
        : samples.sublist(samples.length - _maxSamples);
    await _prefs.setString(
      _key,
      jsonEncode(trimmed.map((s) => s.toJson()).toList()),
    );
  }
}
