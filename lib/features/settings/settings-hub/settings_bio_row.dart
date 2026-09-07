import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat_icon.dart';
import '../../profile/data/profile_repository.dart';

/// Identity block at the top of Settings — Signal's `BioRow`: 80dp avatar,
/// name, then the handles underneath, with a QR button on the right.
///
/// Tapping the name block opens the name editor, which is where Signal puts it
/// too. The QR button stays outside that tap target and opens **your own**
/// code — the thing you hold up for somebody else to scan. It used to open the
/// scanner, which had both people on this screen pointing cameras at each
/// other; the scanner is the icon in the chat list header now.
class SettingsBioRow extends ConsumerWidget {
  const SettingsBioRow({
    super.key,
    required this.user,
    required this.onQrTap,
    required this.onEditName,
    required this.onEditAvatar,
  });

  final AppUser user;
  final VoidCallback onQrTap;
  final VoidCallback onEditName;

  /// Tapping the picture edits the picture; tapping the name edits the name.
  /// Signal splits them the same way — one block, two targets.
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _AvatarButton(user: user, onTap: onEditAvatar),
                  const SizedBox(width: 20),
                  Expanded(child: _Identity(user: user, youLabel: AppTranslations.translate(context, ref, 'settings_you'))),
                ],
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
    // The AbabilX handle first: it is the one a QR code carries and the one
    // people can type into search. A GitHub login only stands in when there is
    // no handle yet, since it is what the sign-in copied across.
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

/// The avatar with the camera badge that says it can be changed.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        height: 78,
        child: Stack(
          children: [
            AppAvatar(
              size: 72,
              url: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
              name: user.name,
              backgroundColor: colors.surfaceContainerHigh,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 13,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
