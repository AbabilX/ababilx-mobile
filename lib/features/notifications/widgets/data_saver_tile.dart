import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../battery_optimization.dart';
import '../native/android_battery.dart';
import '../providers/battery_optimization_provider.dart';
import 'restriction_tile.dart';

/// Shown only while Data Saver is actually applied to this app.
///
/// It is a different block from battery optimization and needs saying on its
/// own: with Data Saver on, Android withholds background network whatever the
/// battery bucket says, so a user who grants the battery exemption and still
/// gets nothing has no way to find out why. Being whitelisted is not being
/// restricted — traffic flows there, so the row stays hidden.
class DataSaverTile extends ConsumerWidget {
  const DataSaverTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!BatteryOptimization.isAndroid) return const SizedBox.shrink();

    return ref
        .watch(batteryRestrictionsProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (restrictions) {
            if (restrictions.dataSaver != DataSaverState.enabled) {
              return const SizedBox.shrink();
            }
            return RestrictionTile(
              title: AppTranslations.translate(
                context,
                ref,
                'data_saver_title',
              ),
              body: AppTranslations.translate(context, ref, 'data_saver_body'),
              solved: false,
              icon: Icons.data_saver_off_rounded,
              onTap: BatteryOptimization.openDataSaverSettings,
            );
          },
        );
  }
}
