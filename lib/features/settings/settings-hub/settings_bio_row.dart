import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat_icon.dart';
import '../../profile/data/profile_repository.dart';

/// Identity block at the top of Settings — Signal's `BioRow`: 80dp avatar,
/// name, then the handles underneath, with a QR button on the right.
///
/// Our QR is not Signal's username link: it opens the scanner that approves a
/// desktop/web sign-in. Same affordance, different job, so it carries a
/// tooltip rather than sitting there bare.
class SettingsBioRow extends StatelessWidget {
  const SettingsBioRow({super.key, required this.user, required this.onQrTap});

  final AppUser user;
  final VoidCallback onQrTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final handle = user.githubUsername.isNotEmpty
        ? '@${user.githubUsername}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          AppAvatar(
            size: 72,
            url: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
            name: user.name,
            backgroundColor: colors.surfaceContainerHigh,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name.isNotEmpty ? user.name : 'You',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.email.isNotEmpty)
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (handle.isNotEmpty)
                  Text(
                    handle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
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
        ],
      ),
    );
  }
}
