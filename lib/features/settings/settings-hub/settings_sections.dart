import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_translations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import 'language_dialog.dart';
import 'settings_row.dart';
import 'sign_out_dialog.dart';

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
        SettingsRow(
          icon: HugeIcons.strokeRoundedMobileNavigator01,
          title: t('settings_app_icon'),
          subtitle: t('settings_app_icon_sub'),
          onTap: () => context.push('/settings/app-icon'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedPaintBoard,
          title: t('settings_wallpaper'),
          subtitle: t('settings_wallpaper_sub'),
          onTap: () => context.push('/settings/wallpaper'),
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
        SettingsRow(
          icon: HugeIcons.strokeRoundedLanguageSkill,
          title: t('app_language'),
          value: languageLabel(user.appLanguage),
          onTap: () async {
            final picked = await showLanguageDialog(context, user.appLanguage);
            if (picked == null) return;
            await ref.read(profileProvider.notifier).updateLanguage(picked);
          },
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedFolderTransfer,
          title: t('settings_local_share'),
          subtitle: t('settings_local_share_sub'),
          onTap: () => context.push('/local-share'),
        ),
        // A handle is what a QR code carries, so it sits directly above the
        // switches that decide who else can find you by one.
        SettingsRow(
          icon: HugeIcons.strokeRoundedAt,
          title: t('settings_username'),
          value: user.username.isEmpty ? null : '@${user.username}',
          subtitle: user.username.isEmpty
              ? t('settings_username_needed')
              : null,
          onTap: () => context.push('/settings/username'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedSearch01,
          title: t('settings_discovery'),
          subtitle: t('settings_discovery_sub'),
          onTap: () => context.push('/settings/discovery'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedUserGroup,
          title: t('chat_people'),
          subtitle: t('settings_people_sub'),
          onTap: () => context.push('/messages/people'),
        ),
        const Divider(height: 24),
        SettingsRow(
          icon: HugeIcons.strokeRoundedQrCode,
          title: t('settings_scan_qr'),
          subtitle: t('settings_scan_qr_sub'),
          onTap: () => QrLoginFlow.start(context, ref),
        ),
        // Same scanner, named for the other job it does. The new device is
        // told to "open AbabilX where your messages already work and scan" —
        // without a row that says messages, the only thing matching that
        // instruction reads as sign-in, and a phone holding the one copy of an
        // account's message key is the only thing that can approve the link.
        SettingsRow(
          icon: HugeIcons.strokeRoundedLink01,
          title: t('settings_link_messages'),
          subtitle: t('settings_link_messages_sub'),
          onTap: () => QrLoginFlow.start(context, ref),
        ),
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
          icon: HugeIcons.strokeRoundedFavourite,
          title: t('settings_donate'),
          subtitle: t('settings_donate_sub'),
          onTap: () => context.push('/settings/donate'),
        ),
        const Divider(height: 24),
        SettingsRow(
          icon: HugeIcons.strokeRoundedLogout01,
          title: t('sign_out'),
          destructive: true,
          onTap: () async {
            if (!await confirmSignOut(context)) return;
            await ref.read(authProvider.notifier).signOut();
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
