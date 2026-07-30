import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';

/// Right app-bar: optional plain status + clean profile avatar.
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
    final status = ref.watch(userStatusForProvider(currentUserId));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status != null) ...[
          // No chip bg — kept short so it never crowds the workspace title.
          UserStatusBadge(
            status: status,
            compact: true,
            plain: true,
            maxWidth: 72,
          ),
          const SizedBox(width: 8),
        ],
        GestureDetector(
          onTap: onProfileTap,
          child: _PillAvatar(name: name, url: avatarUrl),
        ),
      ],
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
