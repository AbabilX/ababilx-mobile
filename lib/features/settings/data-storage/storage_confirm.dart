import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/storage/storage_providers.dart';

/// One confirmation shape for every delete on the storage screens.
///
/// Destructive-looking but not alarming: nothing here loses a message, and a
/// dialog that says otherwise would stop people from using the feature at all.
Future<bool> confirmStorageDelete(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
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
