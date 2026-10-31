import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../data/space_models.dart';

/// The left column of Space icons. The chosen one becomes a rounded square
/// with a pill beside it; an unread one gets a short pill; mentions a badge.
class SpaceRail extends StatelessWidget {
  const SpaceRail({
    super.key,
    required this.spaces,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
  });

  final List<SpaceSummary> spaces;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      key: const Key('space-rail'),
      width: 72,
      color: c.surfaceContainerLow,
      child: ListView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: ShellPillMetrics.contentBottom(context),
        ),
        children: [
          for (final s in spaces)
            _RailItem(
              key: Key('rail-${s.id}'),
              space: s,
              selected: s.id == selectedId,
              onTap: () => onSelect(s.id),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Material(
                color: c.surfaceContainerHigh,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('rail-add'),
                  customBorder: const CircleBorder(),
                  onTap: onAdd,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        color: c.primary,
                        size: 24,
                      ),
                    ),
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

class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.space,
    required this.selected,
    required this.onTap,
  });

  final SpaceSummary space;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final radius = BorderRadius.circular(selected ? 16 : 24);
    const dur = Duration(milliseconds: 180);
    final initials = Center(
      child: Text(
        spaceInitials(space.name),
        style: theme.textTheme.titleSmall?.copyWith(
          color: selected ? c.onPrimary : c.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: space.name,
      child: SizedBox(
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: AnimatedContainer(
                duration: dur,
                width: 4,
                height: selected ? 36 : (space.unread ? 8 : 0),
                decoration: BoxDecoration(
                  color: c.onSurface,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: dur,
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: selected ? c.primary : c.surfaceContainerHighest,
                  borderRadius: radius,
                ),
                child: space.iconUrl.isEmpty
                    ? initials
                    : CachedNetworkImage(
                        imageUrl: space.iconUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => initials,
                        placeholder: (_, _) => initials,
                      ),
              ),
            ),
            if (space.mentions > 0)
              Positioned(
                right: 10,
                bottom: 4,
                child: MentionBadge(count: space.mentions),
              ),
          ],
        ),
      ),
    );
  }
}

/// Red count pill (mentions). 99+ past two digits.
class MentionBadge extends StatelessWidget {
  const MentionBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: c.error,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.surfaceContainerLow, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: c.onError,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
