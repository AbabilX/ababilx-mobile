import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../battery_optimization.dart';
import '../providers/battery_optimization_provider.dart';
import 'restriction_tile.dart';
import '../../../shared/widgets/app_toast.dart';

/// The manual way to grant the battery-optimization exemption.
///
/// Always here, whatever the vitals check decided and whatever the user
/// answered to the prompt. That is deliberate: the automatic prompt is
/// evidence-gated and most users will never see it, so this is where anyone who
/// wants it on day one — or who dismissed the sheet and changed their mind —
/// comes to turn it on.
class BatteryOptimizationTile extends ConsumerWidget {
  const BatteryOptimizationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!BatteryOptimization.isAndroid) return const SizedBox.shrink();

    return ref
        .watch(batteryRestrictionsProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (restrictions) {
            final ignored = restrictions.ignoringBatteryOptimizations;
            // "Restricted" is a harsher bucket than plain optimization, and the
            // copy for optimization understates what the phone is doing.
            final solved = ignored && !restrictions.backgroundRestricted;
            final bodyKey = restrictions.backgroundRestricted
                ? 'battery_opt_restricted_tile_body'
                : ignored
                ? 'battery_opt_ok_body'
                : 'battery_opt_need_body';

            return RestrictionTile(
              title: AppTranslations.translate(
                context,
                ref,
                'battery_opt_title',
              ),
              body: AppTranslations.translate(context, ref, bodyKey),
              solved: solved,
              icon: solved
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_alert_rounded,
              onTap: () {
                if (ignored) {
                  // Doze exemption does not prove OEM sleeping/autostart or
                  // explicit app restrictions are off. Keep settings reachable.
                  BatteryOptimization.openAppSettingsPage();
                } else {
                  _request(context, ref);
                }
              },
            );
          },
        );
  }

  /// A system dialog answered with "don't ask again" never appears again, so a
  /// refusal hands the user the settings screen rather than the same tile.
  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final ok = await BatteryOptimization.requestIgnore();
    ref.invalidate(batteryRestrictionsProvider);
    if (!context.mounted) return;
    showAppToast(
      context,
      AppTranslations.translate(
        context,
        ref,
        ok ? 'battery_opt_enabled' : 'battery_opt_still_denied',
      ),
      isError: !ok,
      actionLabel: ok
          ? null
          : AppTranslations.translate(
              context,
              ref,
              'battery_opt_open_settings',
            ),
      onAction: ok ? null : BatteryOptimization.openBatterySettings,
    );
  }
}
