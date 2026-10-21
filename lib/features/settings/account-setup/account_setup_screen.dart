import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../../profile/providers/profile_provider.dart';
import 'account_email_form.dart';

/// Secure your account: a key-only account (Start New Chat) adds an email
/// and a password, so losing this phone does not lose the account — sign in
/// with them next time. An account that already has an email is sent to the
/// Password screen instead.
class AccountSetupScreen extends ConsumerWidget {
  const AccountSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final email = ref.watch(profileProvider).valueOrNull?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('account_setup_title')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedShieldUser,
                  size: 28,
                  color: colors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    email.isEmpty
                        ? t('account_setup_body')
                        : t('account_setup_done').replaceAll('{email}', email),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (email.isEmpty)
              AccountEmailForm(
                withPassword: true,
                onDone: () {
                  showAppToast(context, t('account_setup_saved'));
                  if (context.canPop()) context.pop();
                },
              )
            else
              FilledButton(
                onPressed: () => context.push('/settings/password'),
                child: Text(t('settings_password')),
              ),
          ],
        ),
      ),
    );
  }
}
