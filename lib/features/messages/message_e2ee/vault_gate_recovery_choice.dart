import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

class VaultGateRecoveryChoice extends ConsumerWidget {
  const VaultGateRecoveryChoice({
    super.key,
    required this.busy,
    required this.onRecover,
    required this.onStartFresh,
    this.onWrongAccount,
    this.hasRecovery = true,
  });

  final bool busy;
  final bool hasRecovery;
  final VoidCallback onRecover;
  final VoidCallback onStartFresh;

  /// Signed in as somebody else — the gate is the first screen that names the
  /// account's messages, so it is where that is noticed, and without a way out
  /// the only escape was Settings behind this very gate. Null where the screen
  /// was reached FROM Settings, which is already past that question.
  final VoidCallback? onWrongAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restore_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              t('recovery_choice_title'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              t(hasRecovery ? 'recovery_choice_body' : 'recovery_legacy_body'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasRecovery)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : onRecover,
                  child: Text(t('recovery_have_code')),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onStartFresh,
                child: Text(t('recovery_fresh')),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t('recovery_fresh_hint'),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onWrongAccount != null) ...[
              const SizedBox(height: 4),
              // A quiet line, not a third button: the two above are the
              // choice, and this is the way out of a choice that does not
              // apply.
              TextButton(
                onPressed: busy ? null : onWrongAccount,
                child: Text(
                  t('recovery_wrong_account'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
