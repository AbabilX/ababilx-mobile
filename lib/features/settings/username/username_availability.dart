import 'username_rules.dart';

/// What the typing check last said about the handle in the field.
enum UsernameAvailability { unknown, checking, free, taken, failed }

/// Next may save only a handle the server has just called free, or the one
/// this account already holds (saving that again must not spend the cooldown).
bool usernameReadyToSave({
  required String typed,
  required String stored,
  required UsernameAvailability availability,
  required String? checkedHandle,
}) {
  final handle = normalizeUsername(typed);
  if (!isValidUsername(handle)) return false;
  if (stored.isNotEmpty && handle == stored) return true;
  return availability == UsernameAvailability.free && checkedHandle == handle;
}
