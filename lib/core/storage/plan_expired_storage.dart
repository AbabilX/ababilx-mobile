import 'package:shared_preferences/shared_preferences.dart';

const _keyPrefix = 'ababilx_plan_expired_dismissed';

String planExpiredDismissKey(String userId, String? premiumUntil) =>
    '$_keyPrefix:$userId:${premiumUntil ?? 'none'}';

Future<bool> isPlanExpiredDialogDismissed(
  String userId,
  String? premiumUntil,
) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(planExpiredDismissKey(userId, premiumUntil)) == '1';
}

Future<void> dismissPlanExpiredDialog(
  String userId,
  String? premiumUntil,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(planExpiredDismissKey(userId, premiumUntil), '1');
}
