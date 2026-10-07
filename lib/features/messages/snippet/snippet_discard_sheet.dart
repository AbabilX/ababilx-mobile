import 'package:flutter/material.dart';

import 'snippet_strings.dart';

/// Asks before typed content is thrown away. True means discard.
Future<bool> confirmSnippetDiscard(
  BuildContext context,
  SnippetStrings strings,
) async {
  final colors = Theme.of(context).colorScheme;
  final discard = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.discardTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(sheet).pop(true),
              child: Text(strings.discard),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(false),
              child: Text(strings.keepEditing),
            ),
          ],
        ),
      ),
    ),
  );
  return discard ?? false;
}
