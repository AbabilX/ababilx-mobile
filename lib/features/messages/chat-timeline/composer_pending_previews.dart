import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'composer_pending_thumb.dart';

/// Pending attachment strip — thumbnails, an "add" tile, and drag to reorder.
///
/// Order matters: it is the order they arrive in the thread. The reference app
/// lets you rearrange the rail before sending, so this one does too —
/// long-press a tile and drag it, rather than removing and re-adding to get the
/// order you wanted.
class ComposerPendingPreviews extends StatelessWidget {
  const ComposerPendingPreviews({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onAddPhoto,
    this.onReorder,
  });

  final List<ChatAttachmentInput> items;
  final ValueChanged<int> onRemove;
  final VoidCallback onAddPhoto;

  /// Null disables dragging — used where the caller keeps no mutable list.
  final void Function(int oldIndex, int newIndex)? onReorder;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reorder = onReorder;

    return SizedBox(
      height: _size + 12,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: reorder != null,
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        itemCount: items.length + 1,
        onReorderItem: (oldIndex, newIndex) {
          if (reorder == null) return;
          // The trailing "add" tile is not draggable and nothing may land
          // after it, so a drop past the last thumbnail lands on it instead.
          if (oldIndex >= items.length) return;
          final last = items.length - 1;
          reorder(oldIndex, newIndex > last ? last : newIndex);
        },
        itemBuilder: (_, i) {
          if (i == items.length) {
            return Padding(
              key: const ValueKey('composer-add-tile'),
              padding: const EdgeInsets.only(left: 8),
              child: _AddPhotoTile(size: _size, onTap: onAddPhoto),
            );
          }
          final attachment = items[i];
          return Padding(
            // Keyed by URL alone: with the index in the key, removing one
            // tile re-keys every tile after it and throws away their elements,
            // so the whole strip re-decodes to delete one photo.
            key: ValueKey('pending-${attachment.fileUrl}'),
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: PendingThumb(
              attachment: attachment,
              size: _size,
              placeholderColor: colors.surfaceContainerHighest,
              onRemove: () => onRemove(i),
            ),
          );
        },
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChatIcon(
                HugeIcons.strokeRoundedCamera01,
                size: 22,
                color: colors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
