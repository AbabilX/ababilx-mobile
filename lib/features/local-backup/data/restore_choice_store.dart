import 'package:shared_preferences/shared_preferences.dart';

/// "Continue with local backup" on the restore-account screen: the person
/// already said yes to the backup before the new message key was made, so the
/// restore that follows asks nothing.
///
/// Kept apart from the restore offer on purpose. The offer is armed by the
/// history reset itself; this only says how that offer should be answered,
/// and where the backup is when Android needed a folder grant to show it.
class RestoreChoiceStore {
  const RestoreChoiceStore();

  static String _key(String userId) => 'local_backup_restore_chosen_$userId';

  /// [folderUri] is the granted folder the backup was found in; null when
  /// this install can read the automatic folder directly.
  Future<void> choose(String userId, {String? folderUri}) async =>
      (await SharedPreferences.getInstance()).setString(
        _key(userId),
        folderUri ?? '',
      );

  Future<bool> chosen(String userId) async =>
      (await SharedPreferences.getInstance()).containsKey(_key(userId));

  Future<String?> folder(String userId) async {
    final uri = (await SharedPreferences.getInstance()).getString(_key(userId));
    return uri == null || uri.isEmpty ? null : uri;
  }

  Future<void> clear(String userId) async =>
      (await SharedPreferences.getInstance()).remove(_key(userId));
}
