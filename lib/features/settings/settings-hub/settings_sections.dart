import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import 'account_rows.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountRows(user: user),
        SettingsRow(
          icon: HugeIcons.strokeRoundedComputerPhoneSync,
          title: 'Linked devices',
          onTap: () => context.push('/profile/devices'),
        ),
        const Divider(height: 24),
        SettingsRow(
          icon: HugeIcons.strokeRoundedNotification03,
          title: 'Notifications',
          onTap: () => context.push('/settings/notifications'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedLanguageSkill,
          title: 'App language',
          value: languageLabel(user.appLanguage),
          onTap: () async {
            final picked = await showLanguageDialog(context, user.appLanguage);
            if (picked == null) return;
            await ref.read(profileProvider.notifier).updateLanguage(picked);
          },
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedFolderTransfer,
          title: 'Local Share',
          subtitle: 'Send files to devices on the same network',
          onTap: () => context.push('/local-share'),
        ),
        if (user.independentChat)
          SettingsRow(
            icon: HugeIcons.strokeRoundedUserGroup,
            title: 'People',
            subtitle: 'Connections, requests and blocked accounts',
            onTap: () => context.push('/messages/people'),
          ),
        const Divider(height: 24),
        SettingsRow(
          icon: HugeIcons.strokeRoundedQrCode,
          title: 'Scan QR to sign in',
          subtitle: 'Approve a sign-in on desktop or web',
          onTap: () => QrLoginFlow.start(context, ref),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedShield01,
          title: 'Privacy policy',
          onTap: () => launchUrl(
            Uri.parse(ApiConstants.webPrivacyPolicyUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedMail01,
          title: 'Invite your friends',
          onTap: () => SharePlus.instance.share(
            ShareParams(
              text:
                  'Try AbabilX — chat, boards and automation in one app. '
                  'https://ababilx.com',
            ),
          ),
        ),
        const Divider(height: 24),
        SettingsRow(
          icon: HugeIcons.strokeRoundedLogout01,
          title: 'Sign out',
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
