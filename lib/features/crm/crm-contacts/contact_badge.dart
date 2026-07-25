import 'package:flutter/material.dart';

/// Small colorful chip — uses theme container colors only.
class ContactBadge extends StatelessWidget {
  const ContactBadge({
    super.key,
    required this.label,
    this.tone = ContactBadgeTone.neutral,
  });

  final String label;
  final ContactBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      ContactBadgeTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ContactBadgeTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ContactBadgeTone.tertiary => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      ContactBadgeTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      ContactBadgeTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.18), width: 0.8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

enum ContactBadgeTone { primary, secondary, tertiary, neutral, error }
