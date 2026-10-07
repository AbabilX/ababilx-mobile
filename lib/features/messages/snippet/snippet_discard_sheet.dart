import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_capsule.dart';
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
            AppCapsule(
              label: strings.discard,
              icon: HugeIcons.strokeRoundedDelete02,
              tint: colors.error,
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
  return discard ?? false;
}
