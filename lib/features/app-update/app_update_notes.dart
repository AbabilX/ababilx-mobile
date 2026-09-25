import 'package:flutter/material.dart';

/// "What's new" heading and the release notes, one line per line written.
///
/// Plain [Text], not SelectableText: the required screen sits above the
/// navigator, where there is no Overlay for a selection toolbar.
class AppUpdateNotes extends StatelessWidget {
  const AppUpdateNotes({super.key, required this.title, required this.notes});

  final String title;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(notes, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
