import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../notifications/battery_optimization.dart';
import '../../notifications/native/android_battery.dart';
import '../../notifications/providers/battery_optimization_provider.dart';
import '../settings-hub/settings_row.dart';

/// The reference app's "Stay connected in the background", as a status line
/// rather than a second switch.
///
/// Every control behind it — the battery exemption, Data Saver, the
/// background-restricted bucket — is a system screen the Notifications page
/// already hands off to. Repeating the switches here would show a toggle the
/// OS can silently disagree with, so this row states what Android is currently
/// doing and opens the page that can do something about it.
class BackgroundConnectionRow extends ConsumerWidget {
  const BackgroundConnectionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsRow(
      icon: HugeIcons.strokeRoundedWifiConnected01,
      title: 'Stay connected in the background',
      subtitle: _subtitle(ref),
      onTap: () => context.push('/settings/notifications'),
    );
  }

  String _subtitle(WidgetRef ref) {
    if (!BatteryOptimization.isAndroid) {
      return 'Messages and calls arrive while AbabilX is closed';
    }
    return ref
        .watch(batteryRestrictionsProvider)
        .maybeWhen(
          data: _describe,
          orElse: () => 'Checking how Android is treating AbabilX…',
        );
  }

  /// Worst restriction first: a user with two of these on needs to hear about
  /// the one that would still block delivery after fixing the other.
  static String _describe(BatteryRestrictions restrictions) {
    if (restrictions.backgroundRestricted) {
      return 'Android is blocking background activity — messages will be late';
    }
    if (restrictions.dataSaver == DataSaverState.enabled) {
      return 'Data Saver is withholding background data from AbabilX';
    }
    if (!restrictions.ignoringBatteryOptimizations) {
      return 'Battery optimization may delay messages and calls';
    }
    return 'Android is letting AbabilX stay reachable';
  }
}
