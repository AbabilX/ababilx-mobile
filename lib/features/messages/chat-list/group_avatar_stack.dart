import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat_icon.dart';

/// WhatsApp-style stacked member avatars — marks a channel/group in the list.
class GroupAvatarStack extends StatelessWidget {
  const GroupAvatarStack({
    super.key,
    required this.avatars,
    this.name,
    this.size = 48,
  });

  final List<String> avatars;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pics = avatars.where((u) => u.trim().isNotEmpty).take(3).toList();

    if (pics.isEmpty) {
      return AppAvatar(
        size: size,
        name: name,
        fallback: ChatIcon(
          HugeIcons.strokeRoundedUserGroup,
          color: colors.onSurfaceVariant,
        ),
      );
    }

    if (pics.length == 1) {
      return AppAvatar(size: size, url: pics.first, name: name);
    }

    // Two (or more): back top-left, front bottom-right — overlapping.
    final tile = size * 0.62;
    final ring = colors.surface;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _RingAvatar(
              size: tile,
              url: pics[0],
              name: name,
              ringColor: ring,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _RingAvatar(
              size: tile,
              url: pics[1],
              name: name,
              ringColor: ring,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingAvatar extends StatelessWidget {
  const _RingAvatar({
    required this.size,
    required this.url,
    required this.ringColor,
    this.name,
  });

  final double size;
  final String url;
  final Color ringColor;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppAvatar.radius + 1),
        border: Border.all(color: ringColor, width: 2),
      ),
      child: AppAvatar(size: size - 4, url: url, name: name),
    );
  }
}
