import 'package:flutter/material.dart';

/// One of the rounded-square actions under the avatar (Call / Mute / Search).
///
/// Signal draws these as a filled square with the label under it, not as an
/// icon button — the label is part of the control, so it is inside the tap
/// target rather than floating beside it.
class DetailsActionButton extends StatelessWidget {
  const DetailsActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  /// Muted / in-call state: the square fills with the accent instead of the
  /// container tint, the way Signal shows a toggle that is currently on.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final background = active
        ? colors.primary
        : colors.primaryContainer.withValues(alpha: enabled ? 1 : 0.4);
    final foreground = active ? colors.onPrimary : colors.onPrimaryContainer;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 68,
                height: 60,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: foreground, size: 24),
                    child: icon,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
