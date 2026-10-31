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
import 'storage_review_list.dart';

/// The reference app's Review storage: everything on disk, biggest first, pick
/// and delete.
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
  static const _tabs = <StorageBucket?>[null, ...StorageBucket.values];

  final _selected = <String>{};
  final _pages = PageController();
  int _tab = 0;

  StorageBucket? get _bucket => _tabs[_tab];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toggle(String key) => setState(() {
    if (!_selected.remove(key)) _selected.add(key);
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                      onPressed: _delete,
                    )
                  : null,
            ),
            StorageBucketFilter(
              value: _bucket,
              // A tap slides to that tab, same as a swipe.
              onChanged: (bucket) => _pages.animateToPage(
                _tabs.indexOf(bucket),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: PageView(
                  controller: _pages,
                  // A swipe mid-selection would drop the picks silently.
                  physics: selecting
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  // A row hidden by another tab must not stay silently
                  // selected — the header count would match nothing on screen.
                  onPageChanged: (index) => setState(() {
                    _tab = index;
                    _selected.clear();
                  }),
                  children: [
                    for (final bucket in _tabs)
                      StorageReviewList(
                        key: ValueKey(bucket),
                        bucket: bucket,
                        selected: _selected,
                        onToggle: _toggle,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final shown =
        ref.read(storageItemsProvider(_bucket)).valueOrNull ?? const [];
    final bytes = shown
        .where((item) => _selected.contains(item.urlKey))
        .fold<int>(0, (sum, item) => sum + item.bytes);
    final confirmed = await confirmStorageDelete(
      context,
      title: 'Delete ${_selected.length} files?',
      body:
          'Frees about ${formatBytes(bytes)}. ${storageDeleteNote(context, ref)}',
    );
    if (!confirmed) return;
    final freed = await ref.read(storageManagerProvider).release(_selected);
    setState(_selected.clear);
    invalidateStorage(ref);
    if (!mounted) return;
    showAppToast(context, 'Freed ${formatBytes(freed)}');
  }
}
