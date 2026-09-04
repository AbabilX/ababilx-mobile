import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../battery_optimization.dart';
import '../native/android_battery.dart';

/// Every background restriction the OS has this app under.
///
/// Invalidated when the user comes back from a system settings screen — the
/// answer changes outside the app, so a value read once at build time goes
/// stale the moment the tile is used.
final batteryRestrictionsProvider = FutureProvider<BatteryRestrictions>(
  (ref) => BatteryOptimization.restrictions(),
);
