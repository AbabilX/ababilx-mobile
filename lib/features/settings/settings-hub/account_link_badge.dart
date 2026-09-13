import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../../profile/data/profile_repository.dart';

enum AccountLink { google, github, slack, qr }

/// How you signed in, plus GitHub/Slack if those are linked — one icon each,
/// no duplicate when GitHub is both the provider and a connection.
List<AccountLink> accountLinks(AppUser user) {
  final links = <AccountLink>[];
  final seen = <AccountLink>{};

  void add(AccountLink link) {
    if (seen.add(link)) links.add(link);
  }

  switch (user.provider.trim().toLowerCase()) {
    case 'google':
      add(AccountLink.google);
    case 'github':
      add(AccountLink.github);
    case 'qr':
      add(AccountLink.qr);
  }
  if (user.githubConnected || user.githubUsername.trim().isNotEmpty) {
    add(AccountLink.github);
  }
  if (user.slackConnected) add(AccountLink.slack);
  return links;
}

extension AccountLinkVisual on AccountLink {
  String get brand => switch (this) {
    AccountLink.google => 'Google',
    AccountLink.github => 'GitHub',
    AccountLink.slack => 'Slack',
    AccountLink.qr => 'QR',
  };

  List<List<dynamic>> get icon => switch (this) {
    AccountLink.google => HugeIcons.strokeRoundedGoogle,
    AccountLink.github => HugeIcons.strokeRoundedGithub,
    AccountLink.slack => HugeIcons.strokeRoundedSlack,
    AccountLink.qr => HugeIcons.strokeRoundedQrCode,
  };
}

/// Tiny mark beside the Settings name. Replaces the gray connection rows.
class AccountLinkBadge extends StatelessWidget {
  const AccountLinkBadge({
    super.key,
    required this.link,
    required this.tooltip,
  });

  final AccountLink link;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: ChatIcon(link.icon, size: 12, color: colors.onSurfaceVariant),
      ),
    );
  }
}
