import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/auth_session.dart';
import '../providers/auth_provider.dart';

class LoginGoogleAction extends StatelessWidget {
  const LoginGoogleAction({
    super.key,
    required this.isLoading,
    required this.label,
    required this.onPressed,
    this.error,
  });

  final bool isLoading;
  final String label;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: 280.ms,
          child: isLoading
              ? const SizedBox(key: ValueKey('login-hidden'))
              : SizedBox(
                  key: const ValueKey('login-button'),
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.surfaceContainerLowest,
                      foregroundColor: colors.onSurface,
                      elevation: 0,
                      side: BorderSide(
                        color: colors.primary.withValues(alpha: 0.18),
                        width: 1.2,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ).animate().fadeIn(delay: 350.ms),
        if (error != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.error.withValues(alpha: 0.2)),
            ),
            child: Text(
              error!,
              style: TextStyle(color: colors.error),
              textAlign: TextAlign.center,
            ),
          ).animate().shake(delay: 100.ms),
        ],
      ],
    );
  }
}

Future<void> runGoogleSignIn(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authProvider.notifier);
  final outcome = await auth.signInWithGoogle();
  if (!context.mounted || outcome is! GoogleAccountSwitchRequired) return;

  String t(String key) => AppTranslations.translate(context, ref, key);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(t('account_switch_title')),
        content: Text(
          t(
            'account_switch_body',
          ).replaceAll('{account}', outcome.accountLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('account_switch_confirm')),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await auth.confirmAccountSwitch();
  } else {
    await auth.cancelAccountSwitch();
  }
}
