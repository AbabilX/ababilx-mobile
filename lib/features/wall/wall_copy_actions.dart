import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hugeicons/hugeicons.dart';

import '../messages/chat_icon.dart';
import 'data/models/wall_models.dart';

const _mediaStoreChannel = MethodChannel('com.ababilx.app/media_store');

/// Long-press action sheet shared by post cards and comment tiles — copy
/// text to clipboard, save images to the device gallery (Slack/WhatsApp-style
/// long-press behavior, same entry points as DM message actions).
Future<void> showWallCopyActions(
  BuildContext context, {
  required String bodyText,
  List<WallAttachment> images = const [],
}) async {
  final hasText = bodyText.trim().isNotEmpty;
  if (!hasText && images.isEmpty) return;

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasText)
            ListTile(
              leading: const Icon(Icons.copy_rounded, size: 22),
              title: const Text('Copy text'),
              onTap: () => Navigator.pop(ctx, 'copy_text'),
            ),
          if (images.isNotEmpty)
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedImage01),
              title: Text(
                images.length == 1
                    ? 'Save image'
                    : 'Save ${images.length} images',
              ),
              onTap: () => Navigator.pop(ctx, 'save_images'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case 'copy_text':
      await copyWallText(context, bodyText);
    case 'save_images':
      await _saveImages(context, images);
  }
}

/// Double-tap action — copy straight to clipboard, no popup (matches DM).
Future<void> copyWallText(BuildContext context, String bodyText) async {
  if (bodyText.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: bodyText));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Copied to clipboard'),
      duration: Duration(seconds: 2),
    ),
  );
}

Future<void> _saveImages(
  BuildContext context,
  List<WallAttachment> images,
) async {
  var saved = 0;
  for (final img in images) {
    try {
      final file = await DefaultCacheManager().getSingleFile(img.fileUrl);
      final path = await _mediaStoreChannel
          .invokeMethod<String>('saveToDownloads', {
            'sourcePath': file.path,
            'fileName': img.fileName,
            'subfolder': 'AbabilXStorage',
            'mimeType': img.contentType.isNotEmpty
                ? img.contentType
                : 'image/jpeg',
            'collection': 'images',
          });
      if (path != null) saved++;
    } catch (_) {
      // Skip failed image, keep saving the rest.
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        saved == 0
            ? 'Could not save image'
            : saved == images.length
            ? (saved == 1
                  ? 'Image saved to gallery'
                  : '$saved images saved to gallery')
            : '$saved of ${images.length} images saved',
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}
