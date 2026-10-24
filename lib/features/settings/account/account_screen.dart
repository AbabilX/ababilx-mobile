import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../profile/providers/profile_provider.dart';
import '../../transfer-chats/ui/transfer_chats_copy.dart';
import '../settings-hub/account_password_row.dart';
import '../settings-hub/settings_row.dart';
import '../settings-hub/sign_out_dialog.dart';
import 'delete_account_sheet.dart';

/// Settings → Account: who you are and where you are signed in. Handle,
/// password, who can find you, signing a computer in, and signing out.
/// Linked devices stays on the Settings hub itself.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    // valueOrNull, never value: a failed profile load must not throw here.
    final user = ref.watch(profileProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('settings_account')),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // A handle is what a QR code carries, so it sits directly
                // above the switches that decide who can find you by one.
                SettingsRow(
                  icon: HugeIcons.strokeRoundedAt,
                  title: t('settings_username'),
                  value: user.username.isEmpty ? null : '@${user.username}',
                  subtitle: user.username.isEmpty
                      ? t('settings_username_needed')
                      : null,
                  onTap: () => context.push('/settings/username'),
                ),
                AccountPasswordRow(user: user),
                SettingsRow(
                  icon: HugeIcons.strokeRoundedSearch01,
                  title: t('settings_discovery'),
                  subtitle: t('settings_discovery_sub'),
                  onTap: () => context.push('/settings/discovery'),
                ),
                const Divider(height: 24),
                SettingsRow(
                  icon: HugeIcons.strokeRoundedQrCode,
                  title: t('settings_scan_qr'),
                  subtitle: t('settings_scan_qr_sub'),
                  onTap: () => QrLoginFlow.start(context, ref),
                ),
                // Same scanner, named for the other job it does. The new
                // device is told to "open AbabilX where your messages already
                // work and scan" — without a row that says messages, the only
                // thing matching that instruction reads as sign-in.
                SettingsRow(
                  icon: HugeIcons.strokeRoundedLink01,
                  title: t('settings_link_messages'),
                  subtitle: t('settings_link_messages_sub'),
                  onTap: () => QrLoginFlow.start(context, ref),
                ),
                // Signal keeps "Transfer account" under Account: moving the
                // whole account to a new phone or a computer.
                if (Platform.isAndroid)
                  SettingsRow(
                    icon: HugeIcons.strokeRoundedSmartPhone02,
                    title: transferText(ref, 'settings_title'),
                    subtitle: transferText(ref, 'settings_sub'),
                    onTap: () =>
                        context.push('/settings/account/transfer-chats'),
                  ),
                const Divider(height: 24),
                SettingsRow(
                  icon: HugeIcons.strokeRoundedLogout01,
                  title: t('sign_out'),
                  destructive: true,
                  onTap: () async {
                    final keyOnly = await ref
                        .read(authRepositoryProvider)
                        .hasAccountKey();
                    if (!context.mounted) return;
                    if (!await confirmSignOut(context, keyOnly: keyOnly)) {
                      return;
                    }
                    await ref.read(authProvider.notifier).signOut();
                  },
                ),
                SettingsRow(
                  icon: HugeIcons.strokeRoundedDelete02,
                  title: t('delete_account'),
                  subtitle: t('delete_account_sub'),
                  destructive: true,
                  onTap: () => showDeleteAccountSheet(context),
                ),
              ],
            ),
    );
  }
}
