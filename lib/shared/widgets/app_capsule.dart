import 'package:flutter/material.dart';

import 'package:hugeicons/hugeicons.dart';

/// The app's capsule: a stadium with a Hugeicons glyph and a label. Filled
/// with [tint] when [selected] or when it states a value, quiet otherwise.
/// Filters, choice chips, small actions — wherever a Material chip or a text
/// button would otherwise sit.
class AppCapsule extends StatelessWidget {
  const AppCapsule({
    super.key,
    required this.label,
    this.icon,
    this.tint,
    this.selected = false,
    this.trailing,
    this.onTap,
    this.expand = false,
  });

  final String label;
  final List<List<dynamic>>? icon;

  /// Null uses the scheme's primary.
  final Color? tint;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Fill the width offered, label left and [trailing] at the far end.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tint ?? scheme.primary;
    final ink = selected ? accent : scheme.onSurface;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: ink,
      ),
    );
    return Opacity(
      opacity: onTap == null && !selected ? 0.55 : 1,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.15)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  HugeIcon(icon: icon!, size: 18, color: ink, strokeWidth: 1.6),
                  const SizedBox(width: 6),
                ],
                expand ? Expanded(child: text) : Flexible(child: text),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
