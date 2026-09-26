import 'package:shared_preferences/shared_preferences.dart';

/// Khaams opened on this phone, by Khaam id. Device-local: there is no server
/// record of an opened Khaam.
class KhaamOpenedStore {
  const KhaamOpenedStore();

  /// Still the first name's key, so cards opened before the rename stay open.
  static const _key = 'ababilx_jpack_opened';

  /// Enough to cover any chat still on the phone; the oldest drop off.
  static const _maxIds = 1000;

  Future<Set<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  Future<void> markOpened(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? const <String>[];
    if (ids.contains(id)) return;
    final next = [...ids, id];
    await prefs.setStringList(
      _key,
      next.length > _maxIds ? next.sublist(next.length - _maxIds) : next,
    );
  }
}
