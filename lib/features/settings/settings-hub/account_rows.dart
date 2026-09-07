import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../profile/data/profile_repository.dart';
import 'settings_row.dart';

/// Read-only account facts that used to be the Profile screen's info panel:
/// which provider signed you in, and which integrations are linked.
///
/// None of these are editable on the phone — GitHub and Slack are both OAuth
/// flows that finish in a browser — so they are stated, not offered as taps
/// that would dead-end.
class AccountRows extends ConsumerWidget {
  const AccountRows({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    String t(String key) => AppTranslations.translate(context, ref, key);
    final github = user.githubUsername.isNotEmpty
        ? '@${user.githubUsername}'
        : t('settings_not_connected');
    final renewsOn = user.premiumUntil?.split('T').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          icon: HugeIcons.strokeRoundedAt,
          title: t('settings_signed_in_with'),
          value: user.provider.isNotEmpty
              ? user.provider.toUpperCase()
              : t('settings_unknown'),
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedGithub,
          title: t('github_connection'),
          value: github,
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedSlack,
          title: t('slack_workspace'),
          value: user.slackConnected
              ? t('settings_connected')
              : t('settings_not_connected'),
          trailing: user.slackConnected
              ? Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.primary,
                )
              : null,
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedCrown,
          title: t('settings_plan'),
          value: user.effectivePlan.toUpperCase(),
          subtitle: renewsOn != null && user.effectivePlan == 'premium'
              ? t('settings_renews').replaceAll('{date}', renewsOn)
              : null,
        ),
      ],
    );
  }
}
