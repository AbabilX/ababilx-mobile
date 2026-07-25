import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android-only battery-optimization helpers (WhatsApp-style unrestricted).
///
/// iOS / web / desktop → no-ops that report "already unrestricted".
class BatteryOptimization {
  BatteryOptimization._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// `true` when the OS will not kill the app for battery savings.
  static Future<bool> isIgnoring() async {
    if (!isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Shows the system "Allow AbabilX to ignore battery optimizations?" dialog.
  /// Returns `true` if unrestricted afterwards.
  static Future<bool> requestIgnore() async {
    if (!isAndroid) return true;
    if (await isIgnoring()) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// Opens OS app settings when the system dialog was denied permanently.
  static Future<bool> openAppSettingsPage() => openAppSettings();
}
