import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'battery_optimization_prompt.dart';

/// Invisible host: shows battery-opt prompt once after login shell mounts.
class BatteryOptimizationBootstrap extends ConsumerStatefulWidget {
  const BatteryOptimizationBootstrap({super.key});

  @override
  ConsumerState<BatteryOptimizationBootstrap> createState() =>
      _BatteryOptimizationBootstrapState();
}

class _BatteryOptimizationBootstrapState
    extends ConsumerState<BatteryOptimizationBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BatteryOptimizationPrompt.maybeShow(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
