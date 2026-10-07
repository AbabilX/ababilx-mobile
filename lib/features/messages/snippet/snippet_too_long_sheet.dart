import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_capsule.dart';
import 'snippet_strings.dart';

/// Shown when a draft is over the message limit. True means "make it a
/// snippet"; the draft is untouched either way.
Future<bool> offerSnippetForLongMessage(
  BuildContext context,
  SnippetStrings strings,
) async {
  final theme = Theme.of(context);
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.tooLongTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              strings.tooLongBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            AppCapsule(
              label: strings.createTitle,
              icon: HugeIcons.strokeRoundedDocumentCode,
              selected: true,
              expand: true,
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            const SizedBox(height: 8),
            AppCapsule(
              label: strings.keepEditing,
              expand: true,
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return accepted ?? false;
}
