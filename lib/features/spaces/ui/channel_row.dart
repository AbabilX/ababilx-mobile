import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/space_models.dart';
import 'space_rail.dart';

/// `# name` (or a megaphone for announcements), a lock for private
/// channels, bold while unread, a red badge for mentions.
class ChannelRow extends StatelessWidget {
  const ChannelRow({super.key, required this.channel, required this.onTap});

  final SpaceChannel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final hot = channel.unread || channel.mentions > 0;
    final color = hot ? c.onSurface : c.onSurfaceVariant;
    final announce = channel.kind == SpaceChannelKind.announcement;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 22,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      HugeIcon(
                        key: announce
                            ? Key('channel-announce-${channel.id}')
                            : null,
                        icon: announce
                            ? HugeIcons.strokeRoundedMegaphone01
                            : HugeIcons.strokeRoundedHashtag,
                        color: color,
                        size: 20,
                      ),
                      if (channel.isPrivate)
                        Positioned(
                          right: -2,
                          top: -3,
                          child: Container(
                            key: Key('channel-lock-${channel.id}'),
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: c.surface,
                              shape: BoxShape.circle,
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSquareLock02,
                              color: color,
                              size: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: hot ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (channel.mentions > 0) MentionBadge(count: channel.mentions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A category's tappable title; the chevron turns when folded.
class CategoryHeader extends StatelessWidget {
  const CategoryHeader({
    super.key,
    required this.category,
    required this.collapsed,
    required this.onTap,
  });

  final SpaceCategory category;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Row(
          children: [
            Flexible(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: c.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: c.onSurfaceVariant,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
