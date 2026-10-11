import 'package:flutter/material.dart';

/// The warning strip above the composer: an identity key changed.
class SafetyNumberStrip extends StatelessWidget {
  const SafetyNumberStrip({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onErrorContainer;
    return Material(
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.gpp_maybe, size: 18, color: ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(color: ink),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}
