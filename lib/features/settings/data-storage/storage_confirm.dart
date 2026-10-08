import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_capsule.dart';
import '../../attachments/storage/storage_providers.dart';

/// One confirmation shape for every delete on the storage screens: a bottom
/// sheet, never a dialog.
///
/// Destructive-looking but not alarming: nothing here loses a message, and a
/// sheet that says otherwise would stop people from using the feature at all.
Future<bool> confirmStorageDelete(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
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
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              AppCapsule(
                label: 'Delete',
                icon: HugeIcons.strokeRoundedDelete02,
                tint: theme.colorScheme.error,
                selected: true,
                expand: true,
                onTap: () => Navigator.of(sheet).pop(true),
              ),
              const SizedBox(height: 8),
              AppCapsule(
                label: 'Cancel',
                expand: true,
                onTap: () => Navigator.of(sheet).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

/// Every screen showing a byte count reads the same three providers, so one
/// call after a delete refreshes all of them.
void invalidateStorage(WidgetRef ref) {
  ref.invalidate(storageUsageProvider);
  ref.invalidate(storageByConversationProvider);
  ref.invalidate(storageItemsProvider);
}
