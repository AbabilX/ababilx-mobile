import 'package:flutter/material.dart';

import 'crm_hex_color.dart';

/// Web `StageChip` — tinted pill + color dot from stage hex.
class StageChip extends StatelessWidget {
  const StageChip({
    super.key,
    required this.name,
    this.colorHex,
    this.showChevron = false,
  });

  final String name;
  final String? colorHex;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parsed = parseCrmHex(colorHex);
    final fg = parsed ?? colors.primary;
    final bg = fg.withValues(alpha: 0.13);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 14, color: colors.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}
