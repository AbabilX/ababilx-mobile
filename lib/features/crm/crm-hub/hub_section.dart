import 'package:flutter/material.dart';

import 'hub_items.dart';
import 'hub_tile.dart';

/// Section title + 4-column icon grid.
class CrmHubSection extends StatelessWidget {
  const CrmHubSection({
    super.key,
    required this.title,
    required this.items,
    required this.labelOf,
    required this.onTileTap,
  });

  final String title;
  final List<CrmHubItem> items;
  final String Function(CrmHubItem item) labelOf;
  final void Function(CrmHubItem item) onTileTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return CrmHubTile(
              item: item,
              label: labelOf(item),
              onTap: () => onTileTap(item),
            );
          },
        ),
      ],
    );
  }
}
