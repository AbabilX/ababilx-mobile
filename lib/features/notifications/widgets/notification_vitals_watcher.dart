import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vitals/battery_prompt_decision.dart';
import '../vitals/notification_vitals.dart';
import 'battery_optimization_prompt.dart';

/// Invisible host for the notification vitals check.
///
/// It replaced a bootstrap that opened the battery-optimization dialog on the
/// first frame after login, before the app had delivered a single push. Signal
/// runs this check on resume instead and only prompts when the evidence has
/// earned it (`VitalsViewModel`), which is what happens here: at most one real
/// check a minute, and in the ordinary case it reads a few preferences, finds
/// no delayed notifications, and says nothing.
class NotificationVitalsWatcher extends ConsumerStatefulWidget {
  const NotificationVitalsWatcher({super.key});

  @override
  ConsumerState<NotificationVitalsWatcher> createState() =>
      _NotificationVitalsWatcherState();
}

class _NotificationVitalsWatcherState
    extends ConsumerState<NotificationVitalsWatcher>
    with WidgetsBindingObserver {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Resume, not launch: the samples that matter are written by the background
  /// isolate while the app is away, so coming back is exactly when the verdict
  /// can have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_running) return;
    _running = true;
    try {
      final vitals = await NotificationVitalsCheck.run();
      if (!mounted) return;
      if (vitals.decision != BatteryPromptDecision.promptBatterySaver) return;
      await BatteryOptimizationPrompt.show(context, ref, vitals.restrictions);
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
