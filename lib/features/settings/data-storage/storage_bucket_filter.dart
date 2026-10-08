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

/// All · Photos · Videos · Audio · Documents, as the app's capsules.
class StorageBucketFilter extends StatelessWidget {
  const StorageBucketFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StorageBucket? value;
  final ValueChanged<StorageBucket?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
      child: Row(
        children: [
          for (final bucket in <StorageBucket?>[null, ...StorageBucket.values])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppCapsule(
                label: bucket?.label ?? 'All',
                icon: storageBucketIcon(bucket),
                selected: value == bucket,
                onTap: () => onChanged(bucket),
              ),
            ),
        ],
      ),
    );
  }
}
