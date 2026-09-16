import 'package:flutter/material.dart';

import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'attachment_gallery.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'signal_bubble_metrics.dart';

class AttachmentImageTile extends StatelessWidget {
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

  /// Solo photo in an overlay bubble: fill [maxWidth], height follows the
  /// file, stop at [maxHeight]. Albums keep a fixed cell.
  bool get _fillWidth => !grid && !inset;

  @override
  Widget build(BuildContext context) {
    final solo = !grid;
    return Padding(
      padding: EdgeInsets.only(top: solo && inset ? 8 : 0),
      child: AttachmentGate(
        attachment: attachment,
        reserveSpace: !_fillWidth,
        height: solo ? SignalBubbleMetrics.mediaDefaultSize : maxHeight,
        width: grid
            ? maxWidth
            : inset
            ? SignalBubbleMetrics.mediaDefaultSize.clamp(minWidth, maxWidth)
            : maxWidth,
        shape: _shape,
        ready: (context, handle) => _ready(context, handle),
      ),
    );
  }

  BorderRadius get _shape =>
      radius ?? (inset ? BorderRadius.circular(8) : BorderRadius.zero);

  Widget _ready(BuildContext context, AttachmentHandle handle) {
    final photo = ClipRRect(
      borderRadius: _shape,
      child: _fillWidth
          ? _sizedPhoto(context, handle)
          : _framedPhoto(context, handle),
    );
    return Stack(
      fit: _fillWidth ? StackFit.loose : StackFit.expand,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: _shape,
            child: photo,
          ),
        ),
        if (overlayText != null)
          Positioned.fill(
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.inverseSurface.withValues(alpha: .82),
              borderRadius: _shape,
              child: InkWell(
                onTap: () => _open(context),
                borderRadius: _shape,
                child: Center(
                  child: Text(
                    overlayText!,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onInverseSurface,
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

  /// Decode-driven height. Width is tight at [maxWidth]; [maxHeight] only
  /// clips a tall file, it is not a size to fill.
  Widget _sizedPhoto(BuildContext context, AttachmentHandle handle) {
    return SizedBox(
      width: maxWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: SignalBubbleMetrics.mediaMinHeight,
          maxHeight: maxHeight,
        ),
        child: Image.file(
          handle.file!,
          width: maxWidth,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _broken(context),
        ),
      ),
    );
  }

  /// Albums and captioned tiles: the model has no dimensions, so keep the
  /// fallback frame stable after decode. The gallery still shows the original.
  Widget _framedPhoto(BuildContext context, AttachmentHandle handle) {
    return Image.file(
      handle.file!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _broken(context),
    );
  }

  Future<void> _open(BuildContext context) => showChatAttachmentGallery(
    context,
    images: gallery,
    index: index,
    preview: preview,
  );

  Widget _broken(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}
