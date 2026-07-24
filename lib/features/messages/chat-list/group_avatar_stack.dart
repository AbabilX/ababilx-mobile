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

    // Always stack for groups — if only one photo, second slot uses initials
    // so it never collapses to a single avatar.
    final first = pics[0];
    final second = pics.length > 1 ? pics[1] : null;
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
              url: first,
              name: name,
              ringColor: ring,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _RingAvatar(
              size: tile,
              url: second,
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
  final String? url;
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
