import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../chat_icon.dart';

/// Right app-bar pill: history (visual only) + profile avatar.
class HeaderProfilePill extends StatelessWidget {
  const HeaderProfilePill({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.onProfileTap,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
        ClipOval(
          child: SizedBox(
            width: 30,
            height: 30,
            child: url != null && url!.isNotEmpty
                ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
                : ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
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
