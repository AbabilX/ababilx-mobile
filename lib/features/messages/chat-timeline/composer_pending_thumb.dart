import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/network_video_player.dart';
import '../../attachments/crypto/sealed_upload.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'pending_preview_cache.dart';

/// One tile in the strip. Draws the local file when we still have it, which is
/// every case except a preview restored after a restart.
class PendingThumb extends StatelessWidget {
  const PendingThumb({
    super.key,
    required this.attachment,
    required this.size,
    required this.placeholderColor,
    required this.onRemove,
  });

  final ChatAttachmentInput attachment;
  final double size;
  final Color placeholderColor;
  final VoidCallback onRemove;

  static final _imageExt = RegExp(
    r'\.(jpe?g|png|gif|webp|bmp|heic|heif)$',
    caseSensitive: false,
  );
  static final _videoExt = RegExp(
    r'\.(mp4|m4v|mov|webm|mkv|avi|3gp)$',
    caseSensitive: false,
  );

  bool get _isImage =>
      attachment.contentType.toLowerCase().startsWith('image/') ||
      _imageExt.hasMatch(attachment.fileName);

  bool get _isVideo =>
      attachment.contentType.toLowerCase().startsWith('video/') ||
      _videoExt.hasMatch(attachment.fileName);

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
              child: _content(colors, MediaQuery.devicePixelRatioOf(context)),
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

  Widget _content(ColorScheme colors, double pixelRatio) {
    final localPath = PendingPreviewCache.get(attachment.fileUrl);
    if (_isImage && localPath != null) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        // The file behind this tile is a full-size export — a 2048x1536 JPEG
        // decodes to ~12 MB of RGBA, and ten of them overrun Flutter's image
        // cache for a strip of 72 px squares. Decode at the size drawn.
        cacheWidth: (size * pixelRatio).round(),
        errorBuilder: (_, _, _) => _remoteImage(colors),
      );
    }
    if (_isImage) return _remoteImage(colors);
    if (_isVideo) {
      return VideoPendingThumb(placeholderColor: placeholderColor, size: size);
    }
    return ColoredBox(
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
    );
  }

  // An upload this phone encrypted (server 0168) is ciphertext at its URL,
  // so there is nothing there to draw; the tile keeps its plate.
  Widget _remoteImage(ColorScheme colors) =>
      _sealed ? ColoredBox(color: placeholderColor) : _networkImage(colors);

  bool get _sealed =>
      attachment.secret != null ||
      SealedUploads.secretFor(attachment.fileUrl) != null;

  Widget _networkImage(ColorScheme colors) => CachedNetworkImage(
    imageUrl: attachment.fileUrl,
    fit: BoxFit.cover,
    placeholder: (_, _) => ColoredBox(color: placeholderColor),
    errorWidget: (_, _, _) => ColoredBox(
      color: placeholderColor,
      child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
    ),
  );
}
