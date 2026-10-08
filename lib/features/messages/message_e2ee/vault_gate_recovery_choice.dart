import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/onboarding/onboarding_option_card.dart';
import '../../../shared/onboarding/onboarding_page.dart';

/// How this phone gets the account's messages — Signal-Android's
/// "Restore or transfer account" (`ArchiveRestoreSelectionScreen`): a title,
/// a line under it, and one card per way in. Starting fresh is a card too,
/// and like Signal's skip it is confirmed first: it cannot be taken back.
class VaultGateRecoveryChoice extends ConsumerWidget {
  const VaultGateRecoveryChoice({
    super.key,
    required this.busy,
    required this.onRecover,
    required this.onStartFresh,
    this.onWrongAccount,
    this.hasRecovery = true,
    this.backupOption,
  });

  final bool busy;
  final bool hasRecovery;
  final VoidCallback onRecover;
  final VoidCallback onStartFresh;

  /// "Continue with local backup", built by the caller: a new message key
  /// like [onStartFresh], then the chats from the backup on this phone.
  final Widget? backupOption;

  /// Signed in as somebody else — the gate is the first screen that names the
  /// account's messages, so it is where that is noticed, and without a way out
  /// the only escape was Settings behind this very gate. Null where the screen
  /// was reached FROM Settings, which is already past that question.
  final VoidCallback? onWrongAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final wrongAccount = onWrongAccount;
    return OnboardingPage(
      title: t('restore_select_title'),
      subtitle: t(hasRecovery ? 'restore_select_body' : 'recovery_legacy_body'),
      gap: 28,
      bottom: wrongAccount == null
          ? null
          : Center(
              child: TextButton(
                onPressed: busy ? null : wrongAccount,
                child: Text(
                  t('recovery_wrong_account'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      children: [
        if (hasRecovery) ...[
          OnboardingOptionCard(
            icon: HugeIcons.strokeRoundedKey01,
            title: t('restore_select_code_title'),
            subtitle: t('restore_select_code_body'),
            enabled: !busy,
            onTap: onRecover,
          ),
          const SizedBox(height: 12),
        ],
        if (backupOption != null) ...[
          backupOption!,
          const SizedBox(height: 12),
        ],
        OnboardingOptionCard(
          icon: HugeIcons.strokeRoundedSendToMobile,
          title: t('restore_select_fresh_title'),
          subtitle: t('restore_select_fresh_body'),
          enabled: !busy,
          onTap: () => _confirmFresh(context, t),
        ),
      ],
    );
  }

  Future<void> _confirmFresh(
    BuildContext context,
    String Function(String) t,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t('restore_skip_title')),
        content: Text(t('recovery_fresh_hint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: Text(t('restore_skip_confirm')),
          ),
        ],
      ),
    );
    if (ok == true) onStartFresh();
  }
}
