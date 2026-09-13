import 'package:flutter/material.dart';

import '../../../../shared/widgets/image_preview_chrome.dart';
import '../../../../shared/widgets/image_preview_dock.dart';
import '../../data/models/chat_models.dart';
import 'chat_media_preview_caption.dart';
import 'chat_media_preview_rail.dart';

/// Caption and rail on the dark strip; Save / Rotate / Share as a capsule.
class ChatMediaPreviewFooter extends StatelessWidget {
  const ChatMediaPreviewFooter({
    super.key,
    required this.images,
    required this.index,
    required this.localPath,
    required this.fileName,
    this.caption,
    required this.onSelect,
    this.onRotate,
  });

  final List<ChatMessageAttachment> images;
  final int index;
  final String? localPath;
  final String fileName;
  final String? caption;
  final ValueChanged<int> onSelect;
  final VoidCallback? onRotate;

  @override
  Widget build(BuildContext context) {
    final captionText = caption?.trim();
    final hasCaption = captionText != null && captionText.isNotEmpty;
    final hasRail = images.length > 1;
    final hasDock = ImagePreviewDock.hasSource(localPath: localPath);
    if (!hasCaption && !hasRail && !hasDock) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasCaption || hasRail)
          Material(
            color: ImagePreviewChrome.bar,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasCaption) ChatMediaPreviewCaption(text: captionText),
                if (hasRail)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: ChatMediaPreviewRail(
                      images: images,
                      index: index,
                      onSelect: onSelect,
                    ),
                  ),
              ],
            ),
          ),
        if (hasDock)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Center(
                child: ImagePreviewDock(
                  fileName: fileName,
                  localPath: localPath,
                  onRotate: onRotate,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
