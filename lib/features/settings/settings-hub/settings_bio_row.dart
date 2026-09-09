import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../../profile/data/profile_repository.dart';

/// Identity under the cover: name, handles, QR. The picture lives on the
/// cover itself now — tapping the name still edits the name.
class SettingsBioRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onEditName,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
              child: _Identity(
                user: user,
                youLabel: AppTranslations.translate(context, ref, 'settings_you'),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Tooltip(
            message: AppTranslations.translate(context, ref, 'settings_your_qr'),
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
  const _Identity({required this.user, required this.youLabel});

  final AppUser user;
  final String youLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final handle = user.username.isNotEmpty
        ? '@${user.username}'
        : user.githubUsername.isNotEmpty
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
                user.name.isNotEmpty ? user.name : youLabel,
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
