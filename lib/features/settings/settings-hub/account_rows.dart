import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../profile/data/profile_repository.dart';
import 'settings_row.dart';

/// Read-only account facts that used to be the Profile screen's info panel:
/// which provider signed you in, and which integrations are linked.
///
/// None of these are editable on the phone — GitHub and Slack are both OAuth
/// flows that finish in a browser — so they are stated, not offered as taps
/// that would dead-end.
class AccountRows extends StatelessWidget {
  const AccountRows({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final github = user.githubUsername.isNotEmpty
        ? '@${user.githubUsername}'
        : 'Not connected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          icon: HugeIcons.strokeRoundedAt,
          title: 'Signed in with',
          value: user.provider.isNotEmpty
              ? user.provider.toUpperCase()
              : 'Unknown',
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedGithub,
          title: 'GitHub',
          value: github,
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedSlack,
          title: 'Slack workspace',
          value: user.slackConnected ? 'Connected' : 'Not connected',
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
          title: 'Plan',
          value: user.effectivePlan.toUpperCase(),
          subtitle: user.premiumUntil != null && user.effectivePlan == 'premium'
              ? 'Renews ${user.premiumUntil!.split('T').first}'
              : null,
        ),
      ],
    );
  }
}
