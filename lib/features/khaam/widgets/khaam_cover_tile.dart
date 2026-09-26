import 'package:flutter/material.dart';

import '../data/khaam_covers.dart';
import 'khaam_cover_art.dart';

const _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// One cover in the gallery grid. The cover already in use is grayed out
/// instead of ringed — desaturated and faded into the page background, so it
/// reads the same in light and dark themes.
class KhaamCoverTile extends StatelessWidget {
  const KhaamCoverTile({
    super.key,
    required this.cover,
    required this.name,
    required this.artWidth,
    required this.selected,
    required this.onTap,
  });

  final KhaamCover cover;
  final String name;
  final double artWidth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'khaam-cover-${cover.id}',
          child: KhaamCoverArt(cover: cover, width: artWidth),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: selected ? colors.onSurfaceVariant : colors.onSurface,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: selected ? 0.45 : 1,
          child: selected
              ? ColorFiltered(colorFilter: _grayscale, child: tile)
              : tile,
        ),
      ),
    );
  }
}
