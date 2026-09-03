import 'package:flutter/material.dart';

import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'attachment_gallery.dart';

class AttachmentImageTile extends StatelessWidget {
  const AttachmentImageTile({
    super.key,
    required this.attachment,
    required this.gallery,
    required this.index,
    required this.maxHeight,
    required this.maxWidth,
    this.grid = false,
    this.overlayText,
    this.radius,
  });

  final ChatMessageAttachment attachment;
  final List<ChatMessageAttachment> gallery;
  final int index;
  final double maxHeight;
  final double maxWidth;
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
        height: solo ? maxHeight * 0.55 : maxHeight,
        width: grid ? maxWidth : null,
        shape: _shape,
        ready: (context, handle) => _ready(context, handle, solo),
      ),
    );
  }

  BorderRadius get _shape => radius ?? BorderRadius.circular(8);

  Widget _ready(BuildContext context, AttachmentHandle handle, bool solo) {
    return Stack(
      fit: grid ? StackFit.expand : StackFit.loose,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: _shape,
            child: ClipRRect(
              borderRadius: _shape,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxHeight,
                  maxWidth: maxWidth,
                  minHeight: 80,
                ),
                child: Image.file(
                  handle.file!,
                  width: double.infinity,
                  height: grid ? maxHeight : null,
                  fit: grid ? BoxFit.cover : BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (_, _, _) => _broken(context, solo),
                ),
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

  Widget _broken(BuildContext context, bool solo) => Container(
    height: 120,
    width: solo ? double.infinity : maxWidth,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}
