import 'package:flutter/material.dart';

/// One button in [SelectionActionBar], or one row of its overflow menu.
class SelectionAction {
  const SelectionAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// Signal's `SignalBottomActionBar`, in the composer's place while messages
/// are selected.
///
/// The overflow rule is Signal's own: every button wants 80dp, and if the
/// items do not all fit, one slot is given back so the last one can be "More".
/// Dropping actions off the end instead — or letting them shrink until the
/// labels wrap to nothing — is how a bar ends up with a Delete nobody can hit.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.items,
    required this.moreLabel,
  });

  final List<SelectionAction> items;
  final String moreLabel;

  /// `minButtonWidthDp` in Signal's bar.
  static const _minButtonWidth = 80.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Material(
          color: scheme.surfaceContainerHigh,
          elevation: 3,
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxButtons = (constraints.maxWidth / _minButtonWidth)
                  .floor()
                  .clamp(1, items.length);
              final usable = items.length <= maxButtons
                  ? items.length
                  : maxButtons - 1;
              final shown = items.take(usable).toList();
              final overflow = items.skip(usable).toList();
              return Row(
                children: [
                  for (final item in shown)
                    Expanded(child: _BarButton(item: item)),
                  if (overflow.isNotEmpty)
                    Expanded(
                      child: _OverflowButton(items: overflow, label: moreLabel),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.item});

  final SelectionAction item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onPressed,
      borderRadius: BorderRadius.circular(18),
      child: _BarContent(icon: item.icon, label: item.label),
    );
  }
}

class _BarContent extends StatelessWidget {
  const _BarContent({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.onSurface),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OverflowButton extends StatelessWidget {
  const _OverflowButton({required this.items, required this.label});

  final List<SelectionAction> items;
  final String label;

  @override
  Widget build(BuildContext context) {
    // The content carries no gesture of its own: an InkWell here would eat the
    // tap before the popup button ever saw it.
    return PopupMenuButton<SelectionAction>(
      tooltip: label,
      position: PopupMenuPosition.over,
      onSelected: (item) => item.onPressed(),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem(
            value: item,
            child: Row(
              children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(item.label)),
              ],
            ),
          ),
      ],
      child: _BarContent(icon: Icons.more_horiz, label: label),
    );
  }
}
