import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Pending attachment strip — image thumbnails + “add photo” tile.
class ComposerPendingPreviews extends StatelessWidget {
  const ComposerPendingPreviews({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onAddPhoto,
  });

  final List<ChatAttachmentInput> items;
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
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == items.length) {
            return _AddPhotoTile(
              size: _size,
              onTap: onAddPhoto,
            );
          }
          final a = items[i];
          return _PendingThumb(
            attachment: a,
            size: _size,
            placeholderColor: colors.surfaceContainerHighest,
            onRemove: () => onRemove(i),
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

class _PendingThumb extends StatelessWidget {
  const _PendingThumb({
    required this.attachment,
    required this.size,
    required this.placeholderColor,
    required this.onRemove,
  });

  final ChatAttachmentInput attachment;
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
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChatIcon(
                              HugeIcons.strokeRoundedFile01,
                              size: 22,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attachment.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
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

Future<void> pickAndUploadImage(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
  ImageSource? source,
}) async {
  final pickedSource = source ??
      await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedImage01),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedCamera01),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
  if (pickedSource == null) return;
  final file = await ImagePicker().pickImage(source: pickedSource);
  if (file == null) return;
  final bytes = await file.readAsBytes();
  final contentType = file.mimeType ?? 'image/jpeg';
  final n = ref.read(chatProvider.notifier);
  final presign = await n.presignAttachment(
    conversationId,
    contentType: contentType,
    fileName: file.name,
    sizeBytes: bytes.length,
  );
  await n.uploadAttachmentBytes(presign, bytes, contentType);
  onAdded(
    ChatAttachmentInput(
      fileUrl: presign.publicUrl,
      fileName: file.name,
      contentType: contentType,
      sizeBytes: bytes.length,
    ),
  );
}
