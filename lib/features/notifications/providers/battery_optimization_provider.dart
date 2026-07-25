import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../battery_optimization.dart';

/// `true` when Android battery optimization is already ignored (unrestricted).
final batteryOptimizationIgnoredProvider = FutureProvider<bool>((ref) {
  return BatteryOptimization.isIgnoring();
});
