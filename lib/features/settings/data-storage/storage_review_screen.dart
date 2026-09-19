import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../../../shared/text/byte_size.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../attachments/storage/storage_providers.dart';
import '../../attachments/storage/storage_usage.dart';
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
    final items = ref.watch(storageItemsProvider(_bucket));
    final selecting = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: selecting
              ? const Icon(Icons.close_rounded)
              : const AppBarBackIcon(),
          onPressed: selecting
              ? () => setState(_selected.clear)
              : () => popOrGoHome(context),
        ),
        title: Text(
          selecting ? '${_selected.length} selected' : 'Review storage',
        ),
        actions: [
          if (selecting)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete',
              onPressed: () => _delete(items.valueOrNull ?? const []),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _BucketFilter(
              value: _bucket,
              onChanged: (bucket) => setState(() {
                _bucket = bucket;
                // A row hidden by the filter must not stay silently selected —
                // the app bar count would then not match anything on screen.
                _selected.clear();
              }),
            ),
            Expanded(
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Could not read local storage')),
                data: (data) => data.isEmpty
                    ? const Center(child: Text('Nothing downloaded here'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
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
              ),
            ),
          ],
        ),
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

class _BucketFilter extends StatelessWidget {
  const _BucketFilter({required this.value, required this.onChanged});

  final StorageBucket? value;
  final ValueChanged<StorageBucket?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final bucket in <StorageBucket?>[null, ...StorageBucket.values])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(bucket?.label ?? 'All'),
                selected: value == bucket,
                onSelected: (_) => onChanged(bucket),
              ),
            ),
        ],
      ),
    );
  }
}
