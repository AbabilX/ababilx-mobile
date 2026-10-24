import 'package:flutter/material.dart';

import '../../chat_icon.dart';

/// Compact squircle action card with icon and label for the You sheet grid.
class YouMenuItem extends StatelessWidget {
  const YouMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.tooltip,
    this.active = false,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;
  final String? tooltip;

  /// A toggle that is on: filled with the accent, so state reads at a glance.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final item = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: active
                      ? colors.primaryContainer
                      : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: active
                        ? colors.primary.withValues(alpha: 0.5)
                        : colors.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: ChatIcon(
                  icon,
                  size: 24,
                  color: active ? colors.onPrimaryContainer : colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.labelSmall?.copyWith(
                  color: active ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        child: Semantics(toggled: active, child: item),
      );
    }
    return item;
  }
}
