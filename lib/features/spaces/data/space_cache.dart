import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'space_models.dart';

/// Tiny key-value seam so tests need no platform channel.
abstract class SpaceKv {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
  Future<void> remove(String key);
}

class PrefsSpaceKv implements SpaceKv {
  final _prefs = SharedPreferencesAsync();
  @override
  Future<String?> get(String key) => _prefs.getString(key);
  @override
  Future<void> set(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// The last good rail and sidebar per account, so Spaces draws instantly
/// and keeps working when the service or the network is down. Small JSON in
/// preferences: the message cache (Drift + FTS5) is phase 5.
class SpaceCache {
  SpaceCache(this.kv, this.account);

  final SpaceKv kv;
  final String account;

  String get _list => 'spaces_list_v1:$account';
  String _tree(String spaceId) => 'spaces_tree_v1:$account:$spaceId';
  String get _selected => 'spaces_selected_v1:$account';
  String get _collapsed => 'spaces_collapsed_v1:$account';

  Future<List<SpaceSummary>?> readList() async {
    final raw = await kv.get(_list);
    return raw == null ? null : SpaceSummary.listFromJson(jsonDecode(raw));
  }

  Future<void> writeList(List<SpaceSummary> list) =>
      kv.set(_list, jsonEncode(SpaceSummary.listToJson(list)));

  Future<SpaceTree?> readTree(String spaceId) async {
    final raw = await kv.get(_tree(spaceId));
    return raw == null ? null : SpaceTree.fromJson(spaceId, jsonDecode(raw));
  }

  Future<void> writeTree(SpaceTree tree) =>
      kv.set(_tree(tree.spaceId), jsonEncode(tree.toJson()));

  Future<String?> readSelected() => kv.get(_selected);
  Future<void> writeSelected(String id) => kv.set(_selected, id);

  Future<Set<String>> readCollapsed() async {
    final raw = await kv.get(_collapsed);
    if (raw == null) return {};
    final v = jsonDecode(raw);
    return {if (v is List) ...v.whereType<String>()};
  }

  Future<void> writeCollapsed(Set<String> ids) =>
      kv.set(_collapsed, jsonEncode(ids.toList()));
}
