import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';

class WallReactionChips extends StatelessWidget {
  const WallReactionChips({
    super.key,
    required this.reactions,
    required this.onTap,
  });

  final List<WallReactionGroup> reactions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final r in reactions)
          InkWell(
            onTap: () => onTap(r.emoji),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: r.reactedByMe
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${r.emoji} ${r.count}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: r.reactedByMe
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
