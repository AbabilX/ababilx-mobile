import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/media/picked_media_file.dart';
import '../../../shared/widgets/network_video_player.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

enum ComposerAttachKind { gallery, camera, file }

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
            return _AddPhotoTile(size: _size, onTap: onAddPhoto);
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

  bool get _isVideo {
    if (attachment.contentType.toLowerCase().startsWith('video/')) return true;
    return RegExp(
      r'\.(mp4|m4v|mov|webm|mkv|avi|3gp)$',
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
                      placeholder: (_, _) =>
                          ColoredBox(color: placeholderColor),
                      errorWidget: (_, _, _) => ColoredBox(
                        color: placeholderColor,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _isVideo
                  ? VideoPendingThumb(
                      placeholderColor: placeholderColor,
                      size: size,
                    )
                  : ColoredBox(
                      color: placeholderColor,
                      child: Tooltip(
                        message: attachment.fileName,
                        child: Center(
                          child: ChatIcon(
                            HugeIcons.strokeRoundedFile01,
                            size: 28,
                            color: colors.onSurfaceVariant,
                          ),
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

Future<ComposerAttachKind?> showComposerAttachSheet(BuildContext context) {
  return showModalBottomSheet<ComposerAttachKind>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedImage01),
            title: const Text('Gallery'),
            subtitle: const Text('Photos & videos'),
            onTap: () => Navigator.pop(ctx, ComposerAttachKind.gallery),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedCamera01),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(ctx, ComposerAttachKind.camera),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedAttachment),
            title: const Text('File'),
            onTap: () => Navigator.pop(ctx, ComposerAttachKind.file),
          ),
        ],
      ),
    ),
  );
}

Future<void> pickAndUploadAttachment(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
  ImageSource? source,
  ComposerAttachKind? kind,
}) async {
  var selectedKind = kind;
  if (selectedKind == null) {
    if (source == ImageSource.gallery) {
      selectedKind = ComposerAttachKind.gallery;
    } else if (source == ImageSource.camera) {
      selectedKind = ComposerAttachKind.camera;
    } else {
      selectedKind = await showComposerAttachSheet(context);
    }
  }
  if (selectedKind == null) return;

  // Native pickers fail on some Android builds if opened while the sheet
  // is still animating closed.
  await Future<void>.delayed(const Duration(milliseconds: 280));

  final picked = switch (selectedKind) {
    ComposerAttachKind.gallery => await pickGalleryImageFile(),
    ComposerAttachKind.camera => await pickLiveCameraFile(),
    ComposerAttachKind.file => await pickDeviceFile(),
  };
  if (picked == null) return;

  final n = ref.read(chatProvider.notifier);
  final presign = await n.presignAttachment(
    conversationId,
    contentType: picked.contentType,
    fileName: picked.fileName,
    sizeBytes: picked.sizeBytes,
  );
  try {
    await n.uploadAttachmentBytes(presign, picked.bytes, picked.contentType);
    onAdded(
      ChatAttachmentInput(
        fileUrl: presign.publicUrl,
        fileName: picked.fileName,
        contentType: picked.contentType,
        sizeBytes: picked.sizeBytes,
      ),
    );
  } catch (_) {
    await n.discardUpload(conversationId, presign.publicUrl);
    rethrow;
  }
}

/// Backwards-compatible alias used by older call sites.
Future<void> pickAndUploadImage(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
  ImageSource? source,
  ComposerAttachKind? kind,
}) => pickAndUploadAttachment(
  context,
  ref,
  conversationId: conversationId,
  onAdded: onAdded,
  source: source,
  kind: kind,
);
