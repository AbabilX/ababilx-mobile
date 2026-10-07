import 'package:flutter/material.dart';

import '../../../shared/widgets/app_capsule.dart';
import 'task_icons.dart';
import 'task_strings.dart';

/// Asks before a typed task is thrown away. True means discard.
Future<bool> confirmTaskDiscard(
  BuildContext context,
  TaskStrings strings,
) async {
  final discard = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.discardTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              AppCapsule(
                label: strings.discard,
                icon: TaskIcons.remove,
                tint: theme.colorScheme.error,
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
      );
    },
  );
  return discard ?? false;
}
