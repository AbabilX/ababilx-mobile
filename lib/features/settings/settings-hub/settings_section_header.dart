import 'package:flutter/material.dart';

/// The reference app's small tinted heading above a group of rows.
///
/// A heading rather than a card: the rows underneath stay full-bleed, so a
/// group reads as one surface and the screen has one vertical rhythm instead
/// of a stack of floating boxes.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
