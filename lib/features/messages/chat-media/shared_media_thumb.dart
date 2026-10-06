import 'package:flutter/material.dart';

import '../../../shared/widgets/video_preview.dart';
import '../../../shared/widgets/video_source.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../chat-timeline/attachment_image_tile.dart';
import '../data/models/chat_models.dart';
import 'shared_media_video_cell.dart';
import '../../chat-lock/media/ram_media_cache.dart';
import '../../chat-lock/media/ram_photo_tile.dart';
import '../../chat-lock/media/ram_photo_viewer.dart';
import '../../chat-lock/media/ram_sealed_media.dart';

/// One square cell in the shared-media strip and grid.
///
/// Pictures reuse the timeline's own tile, so a photo carries the same
/// download gate, the same locked placeholder and the same zoom viewer it has
/// in the conversation — the grid is a second way in, not a second renderer.
///
/// Video deliberately draws a plate rather than a frame: a poster per cell
/// means a decoder per cell, and a screenful of them drains the MediaCodec
/// pool. Tapping opens the real player, which is the one place a decoder is
/// worth holding.
class SharedMediaThumb extends StatelessWidget {
  const SharedMediaThumb({
    super.key,
    required this.attachment,
    required this.gallery,
    required this.size,
    this.ramOnly = false,
  });

  final ChatMessageAttachment attachment;

  /// A locked chat: drawn from memory, never through the attachment store.
  final bool ramOnly;

  /// Every image on this screen, so the viewer can swipe past the tapped one.
  /// Videos are not in it — they open their own player.
  final List<ChatMessageAttachment> gallery;
  final double size;

  static final BorderRadius _radius = BorderRadius.circular(6);

  @override
  Widget build(BuildContext context) {
    if (ramOnly) return _ram(context);
    if (attachment.isImage) {
      final index = gallery.indexOf(attachment);
      return SizedBox(
        width: size,
        height: size,
        child: AttachmentImageTile(
          attachment: attachment,
          gallery: gallery,
          index: index < 0 ? 0 : index,
          maxHeight: size,
          maxWidth: size,
          grid: true,
          radius: _radius,
        ),
      );
    }
    return AttachmentGate(
      attachment: attachment,
      height: size,
      width: size,
      shape: _radius,
      showSize: false,
      ready: (context, handle) => SharedMediaVideoCell(
        localPath: handle.localPath!,
        size: size,
        radius: _radius,
        onTap: () => showVideoPreview(
          context,
          source: VideoSource.file(handle.localPath!),
          fileName: attachment.fileName,
        ),
      ),
    );
  }

  Widget _ram(BuildContext context) {
    // Encrypted files (server 0168) are opened in memory by the cache.
    RamMediaCache.know([attachment, ...gallery]);
    final unreadable = attachment.needsKey;
    if (attachment.isImage && !unreadable) {
      final urls = [
        for (final a in gallery)
          if (!a.needsKey) a.fileUrl,
      ];
      final index = urls.indexOf(attachment.fileUrl);
      return RamPhotoTile(
        url: attachment.fileUrl,
        size: Size.square(size),
        radius: 6,
        onTap: () =>
            showRamPhotos(context, urls: urls, initial: index < 0 ? 0 : index),
      );
    }
    // A plaintext video streams (the empty name keeps Save and Share off); an
    // encrypted one is opened in memory and played from there; one whose key
    // did not open on this phone is a dead tile, never a tile of ciphertext.
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: _radius,
      child: InkWell(
        borderRadius: _radius,
        onTap: unreadable
            ? null
            : attachment.secret != null
            ? () => playRamSealedVideo(
                context,
                attachment,
              ).catchError((_) => false)
            : () => showVideoPreview(
                context,
                source: VideoSource.url(attachment.fileUrl),
                fileName: '',
              ),
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            unreadable ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
            color: unreadable ? colors.onSurfaceVariant : colors.onSurface,
          ),
        ),
      ),
    );
  }
}
