import 'package:flutter/material.dart';

import '../../../../shared/widgets/image_preview_chrome.dart';
import '../../../../shared/widgets/image_preview_dock.dart';
import '../../data/models/chat_models.dart';
import 'chat_media_preview_caption.dart';
import 'chat_media_preview_rail.dart';

/// Caption, album rail, then the Save/Share dock — no overflow menu.
class ChatMediaPreviewFooter extends StatelessWidget {
  const ChatMediaPreviewFooter({
    super.key,
    required this.images,
    required this.index,
    required this.localPath,
    required this.fileName,
    this.caption,
    required this.onSelect,
  });

  final List<ChatMessageAttachment> images;
  final int index;
  final String? localPath;
  final String fileName;
  final String? caption;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final captionText = caption?.trim();
    final hasCaption = captionText != null && captionText.isNotEmpty;
    final hasRail = images.length > 1;
    final hasDock = ImagePreviewDock.hasSource(localPath: localPath);
    if (!hasCaption && !hasRail && !hasDock) {
      return const SizedBox.shrink();
    }
    return Material(
      color: ImagePreviewChrome.bar,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasCaption) ChatMediaPreviewCaption(text: captionText),
            if (hasRail)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ChatMediaPreviewRail(
                  images: images,
                  index: index,
                  onSelect: onSelect,
                ),
              ),
            if (hasDock)
              ImagePreviewDock(fileName: fileName, localPath: localPath),
          ],
        ),
      ),
    );
  }
}
