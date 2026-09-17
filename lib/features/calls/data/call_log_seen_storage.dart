import 'package:shared_preferences/shared_preferences.dart';

const _key = 'ababilx_calls_last_seen_missed_at';

/// When the user last had the Calls tab open — device-local, like the other
/// call prefs. The missed-call badge counts only what arrived after this.
Future<DateTime?> lastSeenMissedCallAt() async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt(_key);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

Future<void> markMissedCallsSeen(DateTime at) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_key, at.millisecondsSinceEpoch);
}
