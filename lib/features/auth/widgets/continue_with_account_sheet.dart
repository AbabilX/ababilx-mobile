import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

enum ContinueWithAccountChoice { google, email }

/// Existing-account ways in: Google or email + password. Shown from the
/// login screen's "Continue with account" button so the start screen stays
/// two choices — Start New Chat, and this sheet.
Future<ContinueWithAccountChoice?> showContinueWithAccountSheet(
  BuildContext context,
) => showModalBottomSheet<ContinueWithAccountChoice>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _Sheet(),
);

class _Sheet extends ConsumerWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    void pick(ContinueWithAccountChoice choice) =>
        Navigator.of(context).pop(choice);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('continue_with_account'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('continue_with_account_body'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            onPressed: () => pick(ContinueWithAccountChoice.google),
            icon: ChatIcon(
              HugeIcons.strokeRoundedGoogle,
              size: 20,
              color: colors.onPrimary,
            ),
            label: Text(t('sign_in_google')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            onPressed: () => pick(ContinueWithAccountChoice.email),
            icon: Icon(
              Icons.mail_outline_rounded,
              size: 20,
              color: colors.onSurface,
            ),
            label: Text(t('sign_in_email_password')),
          ),
        ],
      ),
    );
  }
}
