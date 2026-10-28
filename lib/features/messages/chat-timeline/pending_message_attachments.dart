import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/widgets/file_preview_kind.dart';
import '../../../shared/widgets/preview_icon.dart';
import '../../../shared/widgets/video_pending_thumb.dart';
import '../data/models/chat_models.dart';
import 'pending_preview_cache.dart';
import 'pending_upload_ring.dart';
import 'signal_bubble_metrics.dart';

/// The file being sent, still in preview, with the upload control on it.
///
/// One ring for the whole message: progress is one number, and Cancel stops
/// every byte of this send.
class PendingMessageAttachments extends StatelessWidget {
  const PendingMessageAttachments({
    super.key,
    required this.attachments,
    required this.foreground,
    required this.muted,
    required this.uploading,
    this.progress,
    this.onCancel,
    this.cancelLabel = 'Cancel',
    this.bleed = false,
  });

  final List<ChatAttachmentInput> attachments;
  final Color foreground;
  final Color muted;
  final bool uploading;
  final double? progress;
  final VoidCallback? onCancel;
  final String cancelLabel;

  /// Edge-to-edge inside a media bubble. The bubble clips the corners.
  final bool bleed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photos = attachments.where(_isVisual).toList();
    final files = attachments.where((a) => !_isVisual(a)).toList();
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (photos.isNotEmpty) _photos(photos, scheme),
        for (final file in files) _filePlate(file, scheme),
      ],
    );

    return ClipRRect(
      key: const Key('pending-upload-preview'),
      borderRadius: BorderRadius.circular(bleed ? 0 : 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          preview,
          if (uploading)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: scheme.scrim.withValues(
                    alpha: photos.isEmpty ? 0.12 : 0.28,
                  ),
                ),
              ),
            ),
          if (uploading)
            PendingUploadRing(
              progress: progress,
              label: cancelLabel,
              onPhoto: photos.isNotEmpty,
              onCancel: onCancel,
            ),
        ],
      ),
    );
  }

  Widget _photos(List<ChatAttachmentInput> photos, ColorScheme scheme) {
    final width = SignalBubbleMetrics.mediaMaxWidth;
    if (photos.length == 1) {
      return _frame(photos.first, scheme, width, 180);
    }
    const gap = 2.0;
    final cell = (width - gap) / 2;
    return SizedBox(
      width: width,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final photo in photos.take(4)) _frame(photo, scheme, cell, cell),
        ],
      ),
    );
  }

  Widget _frame(
    ChatAttachmentInput attachment,
    ColorScheme scheme,
    double width,
    double height,
  ) {
    final plate = scheme.surfaceContainerHighest;
    final path = PendingPreviewCache.get(attachment.fileUrl);
    final video = looksLikeVideo(attachment.contentType, attachment.fileName);
    Widget child;
    if (video) {
      child = VideoPendingThumb(placeholderColor: plate, size: height);
    } else if (path != null) {
      child = Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: (width * 2).round(),
        errorBuilder: (_, _, _) => ColoredBox(color: plate),
      );
    } else {
      child = ColoredBox(color: plate);
    }
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _filePlate(ChatAttachmentInput attachment, ColorScheme scheme) {
    final kind = FilePreviewKind.of(
      fileName: attachment.fileName,
      contentType: attachment.contentType,
    );
    return SizedBox(
      width: SignalBubbleMetrics.mediaMaxWidth,
      height: 132,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Stack(
          children: [
            Center(
              child: PreviewIcon(
                kind.icon,
                size: 28,
                color: scheme.onSurfaceVariant,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: foreground, fontSize: 14),
                  ),
                  Text(
                    _formatBytes(attachment.sizeBytes),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isVisual(ChatAttachmentInput attachment) =>
    looksLikeImage(attachment.contentType, attachment.fileName) ||
    looksLikeVideo(attachment.contentType, attachment.fileName);

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
