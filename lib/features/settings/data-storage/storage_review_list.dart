import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/storage/storage_providers.dart';
import '../../attachments/storage/storage_usage.dart';
import 'storage_review_tile.dart';

/// One tab of Review storage: the files of a single kind, biggest first.
class StorageReviewList extends ConsumerWidget {
  const StorageReviewList({
    super.key,
    required this.bucket,
    required this.selected,
    required this.onToggle,
  });

  final StorageBucket? bucket;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    Widget note(String text) => Center(
      child: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
    );
    return ref
        .watch(storageItemsProvider(bucket))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => note('Could not read local storage'),
          data: (data) => data.isEmpty
              ? note('Nothing downloaded here')
              : ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
                  ),
                  itemCount: data.length,
                  itemBuilder: (_, index) {
                    final item = data[index];
                    return StorageReviewTile(
                      item: item,
                      selected: selected.contains(item.urlKey),
                      selecting: selected.isNotEmpty,
                      onToggle: () => onToggle(item.urlKey),
                    );
                  },
                ),
        );
  }
}
