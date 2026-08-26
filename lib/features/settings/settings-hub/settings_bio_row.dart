import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat_icon.dart';
import '../../profile/data/profile_repository.dart';

/// Identity block at the top of Settings — Signal's `BioRow`: 80dp avatar,
/// name, then the handles underneath, with a QR button on the right.
///
/// Tapping the name block opens the name editor, which is where Signal puts it
/// too. The QR button stays outside that tap target: our QR is not Signal's
/// username link, it opens the scanner that approves a desktop/web sign-in.
/// Same affordance, different job, so it carries a tooltip rather than sitting
/// there bare.
class SettingsBioRow extends StatelessWidget {
  const SettingsBioRow({
    super.key,
    required this.user,
    required this.onQrTap,
    required this.onEditName,
  });

  final AppUser user;
  final VoidCallback onQrTap;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onEditName,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
              child: Row(
                children: [
                  AppAvatar(
                    size: 72,
                    url: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                    name: user.name,
                    backgroundColor: colors.surfaceContainerHigh,
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: _Identity(user: user)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Tooltip(
            message: 'Scan QR to sign in',
            child: Material(
              color: colors.surfaceContainerHigh,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onQrTap,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ChatIcon(
                    HugeIcons.strokeRoundedQrCode,
                    size: 20,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final handle = user.githubUsername.isNotEmpty
        ? '@${user.githubUsername}'
        : '';
    final subtitle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                user.name.isNotEmpty ? user.name : 'You',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            ChatIcon(
              HugeIcons.strokeRoundedEdit02,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
        if (user.email.isNotEmpty)
          Text(
            user.email,
            style: subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (handle.isNotEmpty)
          Text(
            handle,
            style: subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
