import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../battery_optimization.dart';
import '../native/android_battery.dart';
import '../providers/battery_optimization_provider.dart';
import '../vitals/notification_vitals.dart';
import '../vitals/vitals_prefs.dart';

/// The one time this app asks about battery optimization on its own.
///
/// Signal's `PromptBatterySaverDialogFragment`: a sheet shown only after the
/// phone has demonstrably been holding notifications back, saying what was
/// measured rather than warning about what might happen. Both buttons answer
/// the question for good — the settings tile is the way back for anyone who
/// changes their mind.
class BatteryOptimizationPrompt {
  BatteryOptimizationPrompt._();

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    BatteryRestrictions restrictions,
  ) async {
    await NotificationVitalsPrefs.markPrompted();
    if (!context.mounted) return;

    final allow = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BatterySaverSheet(restrictions: restrictions),
    );

    // Swiped away rather than answered: the 7-day backoff carries it, and the
    // question can come back. Only a button settles it.
    if (allow == null) return;
    await NotificationVitalsPrefs.markDismissed();
    if (!allow || !context.mounted) return;

    final ok = await BatteryOptimization.requestIgnore();
    ref.invalidate(batteryRestrictionsProvider);
    NotificationVitalsCheck.reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.translate(
            context,
            ref,
            ok ? 'battery_opt_enabled' : 'battery_opt_still_denied',
          ),
        ),
      ),
    );
  }
}

class _BatterySaverSheet extends ConsumerWidget {
  const _BatterySaverSheet({required this.restrictions});

  final BatteryRestrictions restrictions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // "Restricted" is a harsher bucket than plain optimization, and the copy
    // that describes optimization understates what the phone is doing.
    final bodyKey = restrictions.backgroundRestricted
        ? 'battery_opt_restricted_body'
        : 'battery_opt_slow_body';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.battery_alert_rounded, color: colors.error, size: 32),
            const SizedBox(height: 16),
            Text(
              AppTranslations.translate(
                context,
                ref,
                restrictions.backgroundRestricted
                    ? 'battery_opt_restricted_title'
                    : 'battery_opt_slow_title',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.translate(context, ref, bodyKey),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  AppTranslations.translate(
                    context,
                    ref,
                    'battery_opt_continue',
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  AppTranslations.translate(
                    context,
                    ref,
                    'battery_opt_not_now',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
