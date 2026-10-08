import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:hugeicons/hugeicons.dart';

import '../../../shared/text/byte_size.dart';
import '../../attachments/storage/storage_usage.dart';
import '../../messages/chat_icon.dart';
import 'storage_bucket_filter.dart';

/// One file in Review storage: what it is, how big, and when it landed.
///
/// A photo draws its own thumbnail from the local file — the bytes are already
/// on this disk, which is the entire reason the row exists — and everything
/// else gets a type icon. No network is touched by this screen.
class StorageReviewTile extends StatelessWidget {
  const StorageReviewTile({
    super.key,
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onToggle,
  });

  final StorageItem item;
  final bool selected;
  final bool selecting;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: _Thumb(item: item, selected: selected),
      title: Text(
        item.fileName.isEmpty ? item.bucket.label : item.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          formatBytes(item.bytes),
          _when(item.downloadedAtMs),
        ].where((part) => part.isNotEmpty).join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      // Signal's selection circle, in the app's glyphs: no Material checkbox.
      trailing: selecting
          ? ChatIcon(
              selected
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedCircle,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onToggle,
      // Long-press starts a selection the same way the timeline does, so the
      // first tap on this screen can still just be a mis-tap.
      onLongPress: onToggle,
    );
  }

  static String _when(int ms) {
    if (ms <= 0) return '';
    return DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.selected});

  final StorageItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (selected) {
      return CircleAvatar(
        backgroundColor: colors.primary,
        child: ChatIcon(HugeIcons.strokeRoundedTick02, color: colors.onPrimary),
      );
    }
    if (item.bucket == StorageBucket.photos && item.localPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.localPath),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          // A file deleted underneath us must not throw a red box into a list
          // whose whole job is managing files.
          errorBuilder: (_, _, _) => _icon(colors),
          cacheWidth: 120,
        ),
      );
    }
    return _icon(colors);
  }

  Widget _icon(ColorScheme colors) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    alignment: Alignment.center,
    child: ChatIcon(
      storageBucketIcon(item.bucket),
      size: 20,
      color: colors.onSurfaceVariant,
    ),
  );
}
