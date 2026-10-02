import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../../profile/data/profile_repository.dart';

enum AccountLink { google, github, qr }

/// How you signed in — one icon.
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
  return links;
}

extension AccountLinkVisual on AccountLink {
  String get brand => switch (this) {
    AccountLink.google => 'Google',
    AccountLink.github => 'GitHub',
    AccountLink.qr => 'QR',
  };

  List<List<dynamic>> get icon => switch (this) {
    AccountLink.google => HugeIcons.strokeRoundedGoogle,
    AccountLink.github => HugeIcons.strokeRoundedGithub,
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
