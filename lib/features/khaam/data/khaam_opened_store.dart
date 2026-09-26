import 'package:shared_preferences/shared_preferences.dart';

/// JPacks opened on this phone, by JPack id. Device-local: there is no server
/// record of an opened JPack.
class JPackOpenedStore {
  const JPackOpenedStore();

  static const _key = 'ababilx_jpack_opened';

  /// Enough to cover any chat still on the phone; the oldest drop off.
  static const _maxIds = 1000;

  Future<bool> isOpened(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).contains(id);
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
