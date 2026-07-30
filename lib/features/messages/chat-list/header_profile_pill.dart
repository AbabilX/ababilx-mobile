import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat_icon.dart';

/// Right app-bar pill: history (visual only) + status + profile avatar.
class HeaderProfilePill extends ConsumerWidget {
  const HeaderProfilePill({
    super.key,
    required this.name,
    this.avatarUrl,
    this.currentUserId,
    required this.onProfileTap,
  });

  final String name;
  final String? avatarUrl;
  final String? currentUserId;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final status = ref.watch(userStatusForProvider(currentUserId));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedClock01,
              size: 20,
              color: colors.onSurface,
            ),
            if (status != null) ...[
              const SizedBox(width: 6),
              // Kept short so it never crowds out the workspace title on
              // the left — same corner radius as the avatar next to it.
              UserStatusBadge(
                status: status,
                compact: true,
                borderRadius: AppAvatar.radius,
                maxWidth: 72,
              ),
            ],
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onProfileTap,
              child: _PillAvatar(name: name, url: avatarUrl),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillAvatar extends StatelessWidget {
  const _PillAvatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppAvatar(size: 30, url: url, name: name),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
