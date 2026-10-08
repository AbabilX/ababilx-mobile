import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/text/byte_size.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/flat_capsule_header.dart';
import '../../attachments/storage/storage_providers.dart';
import '../../attachments/storage/storage_usage.dart';
import 'storage_bucket_filter.dart';
import 'storage_confirm.dart';
import 'storage_review_tile.dart';

/// Signal's Review storage: everything on disk, biggest first, pick and delete.
///
/// Largest-first is the whole point — the answer to "why is this app using
/// 3 GB" is almost always four videos, and any other order buries them.
class StorageReviewScreen extends ConsumerStatefulWidget {
  const StorageReviewScreen({super.key});

  @override
  ConsumerState<StorageReviewScreen> createState() =>
      _StorageReviewScreenState();
}

class _StorageReviewScreenState extends ConsumerState<StorageReviewScreen> {
  final _selected = <String>{};
  StorageBucket? _bucket;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = ref.watch(storageItemsProvider(_bucket));
    final selecting = _selected.isNotEmpty;

    // Back leaves a selection before it leaves the page.
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        body: Column(
          children: [
            FlatCapsuleHeader(
              title: FlatHeaderLabel(
                selecting ? '${_selected.length} selected' : 'Review storage',
              ),
              action: selecting
                  ? FlatHeaderAction(
                      icon: HugeIcons.strokeRoundedDelete02,
                      label: 'Delete',
                      tint: colors.error,
                      onPressed: () => _delete(items.valueOrNull ?? const []),
                    )
                  : null,
            ),
            StorageBucketFilter(
              value: _bucket,
              onChanged: (bucket) => setState(() {
                _bucket = bucket;
                // A row hidden by the filter must not stay silently selected —
                // the header count would then not match anything on screen.
                _selected.clear();
              }),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: _list(items, selecting, colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    AsyncValue<List<StorageItem>> items,
    bool selecting,
    ColorScheme colors,
  ) {
    Widget note(String text) => Center(
      child: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
    );
    return items.when(
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
                  selected: _selected.contains(item.urlKey),
                  selecting: selecting,
                  onToggle: () => setState(() {
                    if (!_selected.remove(item.urlKey)) {
                      _selected.add(item.urlKey);
                    }
                  }),
                );
              },
            ),
    );
  }

  Future<void> _delete(List<StorageItem> shown) async {
    final bytes = shown
        .where((item) => _selected.contains(item.urlKey))
        .fold<int>(0, (sum, item) => sum + item.bytes);
    final confirmed = await confirmStorageDelete(
      context,
      title: 'Delete ${_selected.length} files?',
      body:
          'Frees about ${formatBytes(bytes)}. The messages stay — media can be '
          'downloaded again.',
    );
    if (!confirmed) return;
    final freed = await ref.read(storageManagerProvider).release(_selected);
    setState(_selected.clear);
    invalidateStorage(ref);
    if (!mounted) return;
    showAppToast(context, 'Freed ${formatBytes(freed)}');
  }
}
