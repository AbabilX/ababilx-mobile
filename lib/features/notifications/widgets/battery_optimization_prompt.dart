import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../battery_optimization.dart';
import '../providers/battery_optimization_provider.dart';

/// One-shot per process: explain + system "ignore battery optimizations" dialog.
class BatteryOptimizationPrompt {
  BatteryOptimizationPrompt._();

  static bool _shownThisProcess = false;

  /// Call after login UI is ready (HomeShell). No-ops if already unrestricted.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    if (!BatteryOptimization.isAndroid) return;
    if (_shownThisProcess) return;
    if (!context.mounted) return;

    final ignored = await BatteryOptimization.isIgnoring();
    if (ignored) {
      _shownThisProcess = true;
      return;
    }
    if (!context.mounted) return;

    _shownThisProcess = true;

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        final colors = theme.colorScheme;
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: colors.outline),
          ),
          title: Text(
            AppTranslations.translate(context, ref, 'battery_opt_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            AppTranslations.translate(context, ref, 'battery_opt_prompt_body'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                AppTranslations.translate(context, ref, 'battery_opt_later'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                AppTranslations.translate(context, ref, 'battery_opt_allow'),
              ),
            ),
          ],
        );
      },
    );

    if (allow != true || !context.mounted) return;

    final ok = await BatteryOptimization.requestIgnore();
    ref.invalidate(batteryOptimizationIgnoredProvider);
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
