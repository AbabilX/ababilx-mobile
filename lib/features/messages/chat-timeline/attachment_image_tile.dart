import 'package:flutter/material.dart';

import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'attachment_gallery.dart';
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

  @override
  Widget build(BuildContext context) {
    final solo = !grid;
    return Padding(
      padding: EdgeInsets.only(top: solo ? 8 : 0),
      child: AttachmentGate(
        attachment: attachment,
        reserveSpace: true,
        height: solo ? SignalBubbleMetrics.mediaDefaultSize : maxHeight,
        width: grid
            ? maxWidth
            : SignalBubbleMetrics.mediaDefaultSize.clamp(minWidth, maxWidth),
        shape: _shape,
        ready: (context, handle) => _ready(context, handle),
      ),
    );
  }

  BorderRadius get _shape => radius ?? BorderRadius.circular(8);

  Widget _ready(BuildContext context, AttachmentHandle handle) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: _shape,
            child: ClipRRect(
              borderRadius: _shape,
              // The model has no dimensions. Keep this fallback frame stable
              // even after decode; the gallery still shows the original shape.
              child: Image.file(
                handle.file!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _broken(context),
              ),
            ),
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

  Future<void> _open(BuildContext context) =>
      showChatAttachmentGallery(context, images: gallery, index: index);

  Widget _broken(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}
