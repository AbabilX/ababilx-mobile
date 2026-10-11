import 'package:shared_preferences/shared_preferences.dart';

/// Whether this account still owes the first-run profile steps on this phone.
///
/// The server's `is_new_account` is a 15-minute window, so it can only START
/// the steps: once they are due the fact is written here as [pending], and a
/// person who closes the app halfway finds them again an hour later.
class ProfileSetupStore {
  const ProfileSetupStore._();

  static const pending = 'pending';
  static const done = 'done';

  static String _key(String userId) => 'profile_setup_v1:$userId';

  /// [pending], [done], or null when never decided for this account.
  static Future<String?> read(String userId) async {
    try {
      return await SharedPreferencesAsync().getString(_key(userId));
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String userId, String value) async {
    try {
      await SharedPreferencesAsync().setString(_key(userId), value);
    } catch (_) {
      // The steps still run for this launch.
    }
  }
}

/// Started but not finished, or a brand-new account that never saw them.
/// An account that was not new when first seen is never asked.
bool profileSetupDue({required bool isNewAccount, required String? stored}) =>
    stored == ProfileSetupStore.pending || (stored == null && isNewAccount);
