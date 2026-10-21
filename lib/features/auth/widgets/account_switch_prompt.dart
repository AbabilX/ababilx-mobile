import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/auth_session.dart';
import '../providers/auth_provider.dart';

/// Asks before a sign-in replaces another account's data on this phone, then
/// finishes or abandons the waiting session. Every sign-in method ends here,
/// so none of them can wipe a phone without the question being asked.
Future<void> settleAccountSwitch(
  BuildContext context,
  WidgetRef ref,
  SignInOutcome outcome,
) async {
  if (outcome is! AccountSwitchRequired) return;
  final auth = ref.read(authProvider.notifier);
  String t(String key) => AppTranslations.translate(context, ref, key);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(t('account_switch_title')),
        content: Text(
          t('account_switch_body').replaceAll(
            '{account}',
            outcome.accountLabel.isEmpty
                ? t('account_switch_new_account')
                : outcome.accountLabel,
          ),
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
