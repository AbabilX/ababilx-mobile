import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_translations.dart';
import '../../profile/data/profile_repository.dart';
import 'settings_row.dart';
import '../donate/donate_sheet.dart';

/// The row groups under the bio block. Signal splits these with dividers
/// rather than cards, so each group reads as one surface.
class SettingsSections extends ConsumerWidget {
  const SettingsSections({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle, password, discovery, QR sign-in and sign out: everything
        // about the account itself, behind one row.
        SettingsRow(
          icon: HugeIcons.strokeRoundedUserAccount,
          title: t('settings_account'),
          subtitle: t('settings_account_sub'),
          onTap: () => context.push('/settings/account'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedComputerPhoneSync,
          title: t('devices_title'),
          onTap: () => context.push('/profile/devices'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedNotification03,
          title: t('settings_notifications'),
          onTap: () => context.push('/settings/notifications'),
        ),
        // Language, tabs (which show, their order, the launch tab), app icon
        // and chat wallpaper: everything about how the app looks, behind one
        // row.
        SettingsRow(
          icon: HugeIcons.strokeRoundedPaintBoard,
          title: t('settings_appearance'),
          subtitle: t('settings_appearance_sub'),
          onTap: () => context.push('/settings/appearance'),
        ),
        // Sent media quality lives inside this screen now, next to the
        // auto-download and storage settings it belongs with — one address
        // for every question about what this app costs in bytes.
        SettingsRow(
          icon: HugeIcons.strokeRoundedDatabase01,
          title: t('settings_data_storage'),
          subtitle: t('settings_data_storage_sub'),
          onTap: () => context.push('/settings/data-storage'),
        ),
        // Local Share hub is intentionally hidden from Settings for now;
        // the feature (route + sync) stays wired for a later re-enable.
        SettingsRow(
          icon: HugeIcons.strokeRoundedShield01,
          title: t('settings_privacy_mode'),
          subtitle: t('settings_privacy_mode_sub'),
          onTap: () => context.push('/settings/privacy-mode'),
        ),
        // The second door to locked chats, for whoever never learns the long
        // press on the AbabilX title. Always shown, locks or not, so the row
        // itself never says whether this phone has any.
        SettingsRow(
          icon: HugeIcons.strokeRoundedSquareLock02,
          title: t('chatlock_folder_title'),
          subtitle: t('settings_locked_chats_sub'),
          onTap: () => context.push('/messages/locked'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedUserGroup,
          title: t('chat_people'),
          subtitle: t('settings_people_sub'),
          onTap: () => context.push('/messages/people'),
        ),
        const Divider(height: 24),
        SettingsRow(
          icon: HugeIcons.strokeRoundedShield01,
          title: t('settings_privacy'),
          onTap: () => launchUrl(
            Uri.parse(ApiConstants.webPrivacyPolicyUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedMail01,
          title: t('settings_invite'),
          onTap: () => SharePlus.instance.share(
            ShareParams(text: t('settings_invite_text')),
          ),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedMoneySend01,
          title: t('settings_donate'),
          subtitle: t('settings_donate_sub'),
          onTap: () => showDonateSheet(context),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
