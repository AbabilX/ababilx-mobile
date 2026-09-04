import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// How Data Saver treats this app specifically — not the global switch.
enum DataSaverState {
  /// Off, or this network is not metered.
  disabled,

  /// On, but this app is exempt, so background traffic still flows.
  whitelisted,

  /// On and applied here: background network is withheld regardless of doze.
  enabled,
}

/// The background restrictions Android currently has this app under.
class BatteryRestrictions {
  const BatteryRestrictions({
    this.ignoringBatteryOptimizations = true,
    this.dataSaver = DataSaverState.disabled,
    this.backgroundRestricted = false,
    this.deviceIdle = false,
    this.manufacturer = '',
    this.model = '',
  });

  /// What every non-Android platform reports: nothing to fix here.
  static const unrestricted = BatteryRestrictions();

  factory BatteryRestrictions.fromMap(Map<Object?, Object?> map) =>
      BatteryRestrictions(
        ignoringBatteryOptimizations:
            map['ignoringBatteryOptimizations'] != false,
        dataSaver: _dataSaver(map['dataSaver']?.toString()),
        backgroundRestricted: map['backgroundRestricted'] == true,
        deviceIdle: map['deviceIdle'] == true,
        manufacturer: map['manufacturer']?.toString() ?? '',
        model: map['model']?.toString() ?? '',
      );

  final bool ignoringBatteryOptimizations;
  final DataSaverState dataSaver;
  final bool backgroundRestricted;
  final bool deviceIdle;
  final String manufacturer;
  final String model;

  static DataSaverState _dataSaver(String? code) => switch (code) {
    'enabled' => DataSaverState.enabled,
    'whitelisted' => DataSaverState.whitelisted,
    _ => DataSaverState.disabled,
  };

  @override
  String toString() =>
      'BatteryRestrictions(ignoring: $ignoringBatteryOptimizations, '
      'dataSaver: ${dataSaver.name}, backgroundRestricted: '
      '$backgroundRestricted, idle: $deviceIdle, $manufacturer $model)';
}

/// Reads [BatteryRestrictions] from `BatteryState.kt`.
///
/// `permission_handler` answers only the battery-optimization bit. Data Saver
/// and background-restricted come from `ConnectivityManager` and
/// `ActivityManager`, and they decide whether asking for the exemption would
/// change anything at all — so this bridge exists to read them.
class AndroidBattery {
  AndroidBattery._();

  static const _channel = MethodChannel('com.ababilx.app/battery');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<BatteryRestrictions> status() async {
    if (!supported) return BatteryRestrictions.unrestricted;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('status');
      if (map == null) return BatteryRestrictions.unrestricted;
      return BatteryRestrictions.fromMap(map);
    } on PlatformException {
      return BatteryRestrictions.unrestricted;
    } on MissingPluginException {
      // Older host without the channel — a build that simply never prompts.
      return BatteryRestrictions.unrestricted;
    }
  }

  /// Battery-optimization settings list, falling back to app details.
  static Future<bool> openSettings() => _open('openSettings');

  /// Data Saver's per-app exception list, falling back to data usage.
  static Future<bool> openDataSaverSettings() => _open('openDataSaverSettings');

  static Future<bool> _open(String method) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
