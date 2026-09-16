import 'package:shared_preferences/shared_preferences.dart';

/// JPacks opened on this phone, by JPack id. Device-local like the demo
/// wallet: there is no server record of an opened JPack yet.
class JPackClaimsStore {
  const JPackClaimsStore();

  static const _key = 'ababilx_jpack_claimed';

  Future<bool> isClaimed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).contains(id);
  }

  Future<void> markClaimed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? const <String>[];
    if (ids.contains(id)) return;
    await prefs.setStringList(_key, [...ids, id]);
  }
}
