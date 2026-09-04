import 'package:permission_handler/permission_handler.dart';

import 'native/android_battery.dart';
import 'vitals/push_latency_store.dart';

/// Android battery-optimization exemption: read it, ask for it, escape to
/// settings when the dialog has been refused for good.
///
/// The *reading* is native ([AndroidBattery]) because the exemption bit alone
/// does not say whether asking would help — see `BatteryState.kt`. The *asking*
/// stays on `permission_handler`, which runs the system dialog as an activity
/// result and can therefore report what the user chose.
///
/// iOS / web / desktop → no-ops that report "already unrestricted".
class BatteryOptimization {
  BatteryOptimization._();

  static bool get isAndroid => AndroidBattery.supported;

  /// Every background restriction the OS has this app under.
  static Future<BatteryRestrictions> restrictions() => AndroidBattery.status();

  /// `true` when the OS will not throttle the app for battery savings.
  static Future<bool> isIgnoring() async =>
      (await AndroidBattery.status()).ignoringBatteryOptimizations;

  /// Shows the system "Allow AbabilX to ignore battery optimizations?" dialog.
  /// Returns `true` if unrestricted afterwards.
  static Future<bool> requestIgnore() async {
    if (!isAndroid) return true;
    if (await isIgnoring()) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) {
      // The latency on record was measured under the old restrictions, so it
      // says nothing about this phone any more — and left in place it would
      // keep the "notifications are slow" verdict alive for a week after the
      // thing causing it was fixed.
      await PushLatencyStore.clear();
    }
    return status.isGranted;
  }

  /// The battery-optimization settings list — where a user whose answer to the
  /// system dialog was "don't ask again" has to go.
  static Future<bool> openBatterySettings() => AndroidBattery.openSettings();

  /// Data Saver's exception list. A different screen and a different block:
  /// with Data Saver applied, the battery exemption grants nothing.
  static Future<bool> openDataSaverSettings() =>
      AndroidBattery.openDataSaverSettings();

  /// Opens OS app settings when the system dialog was denied permanently.
  static Future<bool> openAppSettingsPage() => openAppSettings();
}
