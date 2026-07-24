import 'package:flutter/foundation.dart';

/// Central FCM/debug logger — filter Logcat / console with `[fcm]`.
void fcmLog(String step, [Object? detail]) {
  if (detail == null) {
    debugPrint('[fcm] $step');
    return;
  }
  debugPrint('[fcm] $step | $detail');
}

String fcmTokenPreview(String? token) {
  if (token == null || token.isEmpty) return '(null)';
  if (token.length <= 12) return token;
  return '${token.substring(0, 8)}…${token.substring(token.length - 4)}';
}
