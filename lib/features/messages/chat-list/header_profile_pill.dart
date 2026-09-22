import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';

/// Chat-list header avatar — status lives in the title slot, not beside this.
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
    return GestureDetector(
      onTap: onProfileTap,
      child: _PillAvatar(name: name, url: avatarUrl),
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
