import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'attachment_gallery.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'media_frame.dart';
import 'media_frame_lock.dart';
import 'signal_bubble_metrics.dart';

class AttachmentImageTile extends ConsumerStatefulWidget {
  const AttachmentImageTile({
    super.key,
    required this.attachment,
    required this.gallery,
    required this.index,
    required this.maxHeight,
    required this.maxWidth,
    this.minWidth = 0,
    this.grid = false,
    this.overlayText,
    this.radius,
    this.preview,
    this.inset = true,
  });

  final ChatMessageAttachment attachment;
  final List<ChatMessageAttachment> gallery;
  final int index;
  final double maxHeight;
  final double maxWidth;

  /// Captioned pictures reserve a wider frame before their bytes arrive.
  /// Album cells size themselves and ignore this floor.
  final double minWidth;

  final bool grid;
  final String? overlayText;

  /// Album cells share cut corners so the group reads as one rounded block.
  /// Null means the standalone shape.
  final BorderRadius? radius;

  /// Sender + time + caption for the fullscreen viewer. Shared-media cells
  /// leave this null; the viewer titles itself "Photo".
  final ChatMediaPreviewMeta? preview;

  /// Caption / quoted pictures keep an 8dp gap and inner radius so they sit
  /// inside the bubble. Overlay bubbles turn this off so the photo *is* the
  /// bubble and the time sits on the image, not in a chrome strip.
  final bool inset;

  @override
  ConsumerState<AttachmentImageTile> createState() =>
      _AttachmentImageTileState();
}

class _AttachmentImageTileState extends ConsumerState<AttachmentImageTile>
    with MediaFrameLock {
  @override
  ChatMessageAttachment get framedAttachment => widget.attachment;

  /// The box this picture occupies through lookup, download and decode alike.
  /// A solo photo in an overlay bubble fits inside maxW×maxH keeping aspect
  /// (width shrinks for tall files); albums and captioned tiles keep a fixed
  /// frame and crop into it.
  Size get _box {
    final w = widget;
    if (w.grid) return Size(w.maxWidth, w.maxHeight);
    if (w.inset) {
      const side = SignalBubbleMetrics.mediaDefaultSize;
      return Size(side.clamp(w.minWidth, w.maxWidth), side);
    }
    return soloMediaSize(
      lockedDimensions,
      maxWidth: w.maxWidth,
      maxHeight: w.maxHeight,
      minWidth: w.minWidth,
    );
  }

  BorderRadius get _shape =>
      widget.radius ??
      (widget.inset ? BorderRadius.circular(8) : BorderRadius.zero);

  @override
  Widget build(BuildContext context) {
    final box = _box;
    return Padding(
      padding: EdgeInsets.only(top: !widget.grid && widget.inset ? 8 : 0),
      child: AttachmentGate(
        attachment: widget.attachment,
        reserveSpace: true,
        height: box.height,
        width: box.width,
        shape: _shape,
        ready: (context, handle) => _ready(context, handle, box),
      ),
    );
  }

  Widget _ready(BuildContext context, AttachmentHandle handle, Size box) {
    final colors = Theme.of(context).colorScheme;
    final photo = ClipRRect(
      borderRadius: _shape,
      // The placeholder's own fill stays under the picture, so the first
      // decode fades in over the same colour the tile was already showing.
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Image(
          image: displaySizedImage(
            FileImage(handle.file!),
            box: box,
            size: handle.dimensions ?? lockedDimensions,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          width: box.width,
          height: box.height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: fadeInImageFrame,
          errorBuilder: (_, _, _) => _broken(context),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(onTap: _open, borderRadius: _shape, child: photo),
        ),
        if (widget.overlayText != null)
          Positioned.fill(
            child: Material(
              color: colors.inverseSurface.withValues(alpha: .82),
              borderRadius: _shape,
              child: InkWell(
                onTap: _open,
                borderRadius: _shape,
                child: Center(
                  child: Text(
                    widget.overlayText!,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _open() => showChatAttachmentGallery(
    context,
    images: widget.gallery,
    index: widget.index,
    preview: widget.preview,
  );

  Widget _broken(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}
