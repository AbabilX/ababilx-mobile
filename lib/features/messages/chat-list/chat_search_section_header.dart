import 'package:flutter/material.dart';

/// Signal's search section label (`contact_search_section_header`: 16/12 pad,
/// TitleSmall). Empty sections are not drawn — the parent omits this widget.
class ChatSearchSectionHeader extends StatelessWidget {
  const ChatSearchSectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
