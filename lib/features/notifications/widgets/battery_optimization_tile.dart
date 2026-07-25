import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../battery_optimization.dart';
import '../providers/battery_optimization_provider.dart';

/// Profile preference: Android battery unrestricted status + tap to enable.
class BatteryOptimizationTile extends ConsumerWidget {
  const BatteryOptimizationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!BatteryOptimization.isAndroid) return const SizedBox.shrink();

    final ignoredAsync = ref.watch(batteryOptimizationIgnoredProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ignoredAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (ignored) {
        final title = AppTranslations.translate(
          context,
          ref,
          'battery_opt_title',
        );
        final body = AppTranslations.translate(
          context,
          ref,
          ignored ? 'battery_opt_ok_body' : 'battery_opt_need_body',
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: ignored
                  ? null
                  : () async {
                      final ok = await BatteryOptimization.requestIgnore();
                      ref.invalidate(batteryOptimizationIgnoredProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppTranslations.translate(
                              context,
                              ref,
                              ok
                                  ? 'battery_opt_enabled'
                                  : 'battery_opt_still_denied',
                            ),
                          ),
                        ),
                      );
                    },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      ignored
                          ? Icons.battery_charging_full_rounded
                          : Icons.battery_alert_rounded,
                      color: ignored ? colors.primary : colors.error,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!ignored)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      )
                    else
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
