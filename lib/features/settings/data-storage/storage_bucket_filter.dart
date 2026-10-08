import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_capsule.dart';
import '../../attachments/storage/storage_usage.dart';

/// The glyph for one kind of stored file, shared by the filter and the rows.
List<List<dynamic>> storageBucketIcon(StorageBucket? bucket) =>
    switch (bucket) {
      null => HugeIcons.strokeRoundedFolder01,
      StorageBucket.photos => HugeIcons.strokeRoundedImage01,
      StorageBucket.videos => HugeIcons.strokeRoundedVideo01,
      StorageBucket.audio => HugeIcons.strokeRoundedMic01,
      StorageBucket.documents => HugeIcons.strokeRoundedFile01,
    };

/// All · Photos · Videos · Audio · Documents, as the app's capsules. The
/// strip scrolls the chosen one into view, so a swipe between tabs never
/// leaves the highlight off-screen.
class StorageBucketFilter extends StatefulWidget {
  const StorageBucketFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StorageBucket? value;
  final ValueChanged<StorageBucket?> onChanged;

  @override
  State<StorageBucketFilter> createState() => _StorageBucketFilterState();
}

class _StorageBucketFilterState extends State<StorageBucketFilter> {
  static const _all = <StorageBucket?>[null, ...StorageBucket.values];

  final _keys = {for (final bucket in _all) bucket: GlobalKey()};

  @override
  void didUpdateWidget(StorageBucketFilter old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    final target = _keys[widget.value]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
      child: Row(
        children: [
          for (final bucket in _all)
            Padding(
              key: _keys[bucket],
              padding: const EdgeInsets.only(right: 8),
              child: AppCapsule(
                label: bucket?.label ?? 'All',
                icon: storageBucketIcon(bucket),
                selected: widget.value == bucket,
                onTap: () => widget.onChanged(bucket),
              ),
            ),
        ],
      ),
    );
  }
}
