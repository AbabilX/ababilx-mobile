import 'package:flutter/material.dart';

class CallFilterAction extends StatelessWidget {
  const CallFilterAction({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return IconButton.filledTonal(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon),
      );
    }
    return IconButton(onPressed: onPressed, tooltip: label, icon: Icon(icon));
  }
}

class CallSectionHeader extends StatelessWidget {
  const CallSectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
