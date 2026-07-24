import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import '../providers/wall_state.dart';

class WallFeedFilters extends StatelessWidget {
  const WallFeedFilters({
    super.key,
    required this.filter,
    required this.categories,
    required this.onSelect,
  });

  final WallFeedFilter filter;
  final List<WallCategory> categories;
  final ValueChanged<WallFeedFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          _chip('All', filter.kind == WallFeedKind.all, () {
            onSelect(const WallFeedFilter.all());
          }),
          _chip('Mine', filter.kind == WallFeedKind.mine, () {
            onSelect(const WallFeedFilter.mine());
          }),
          _chip('Saved', filter.kind == WallFeedKind.saved, () {
            onSelect(const WallFeedFilter.saved());
          }),
          for (final c in categories)
            _chip(
              c.label,
              filter.kind == WallFeedKind.category && filter.category == c.slug,
              () => onSelect(WallFeedFilter.category(c.slug)),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}
