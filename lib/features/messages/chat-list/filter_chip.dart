import 'package:flutter/material.dart';

import '../chat_icon.dart';

/// One pill of the chat-list tab row.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onLongPress,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.transparent : colors.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                ChatIcon(icon!, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
