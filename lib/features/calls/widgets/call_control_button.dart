import 'package:flutter/material.dart';

/// Round labelled call action (Accept, Decline, Mute, …).
///
/// Shared by the 1:1 call screen and the channel group-call invite so both
/// ringing surfaces present the same buttons in the same places.
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg =
        background ??
        (selected ? colors.primary : colors.surfaceContainerHighest);
    final fg = foreground ?? (selected ? colors.onPrimary : colors.onSurface);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.45),
            disabledForegroundColor: fg.withValues(alpha: 0.45),
            minimumSize: const Size(64, 64),
          ),
          icon: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
