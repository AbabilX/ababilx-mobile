import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/models/wall_models.dart';

/// Pending wall attachments — thumbnails + add-photo tile (camera/gallery).
class WallPendingPreviews extends StatelessWidget {
  const WallPendingPreviews({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onAddPhoto,
  });

  final List<WallAttachmentInput> items;
  final ValueChanged<int> onRemove;
  final VoidCallback onAddPhoto;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == items.length) {
            return _AddTile(size: _size, onTap: onAddPhoto);
          }
          return _Thumb(
            attachment: items[i],
            size: _size,
            placeholderColor: colors.surfaceContainerHighest,
            onRemove: () => onRemove(i),
          );
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.size, required this.onTap});

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

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.attachment,
    required this.size,
    required this.placeholderColor,
    required this.onRemove,
  });

  final WallAttachmentInput attachment;
  final double size;
  final Color placeholderColor;
  final VoidCallback onRemove;

  bool get _isImage {
    if (attachment.contentType.toLowerCase().startsWith('image/')) return true;
    return RegExp(
      r'\.(jpe?g|png|gif|webp|bmp|heic|heif)$',
      caseSensitive: false,
    ).hasMatch(attachment.fileName);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isImage
                  ? CachedNetworkImage(
                      imageUrl: attachment.fileUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: placeholderColor),
                      errorWidget: (_, _, _) => ColoredBox(
                        color: placeholderColor,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ColoredBox(
                      color: placeholderColor,
                      child: Center(
                        child: ChatIcon(
                          HugeIcons.strokeRoundedFile01,
                          size: 22,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Material(
              color: colors.surface,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
