import 'package:flutter/material.dart';

import 'image_preview_chrome.dart';
import 'image_preview_dock.dart';

/// Caption on the dark strip; Save / Open / Share as a capsule.
class FilePreviewFooter extends StatelessWidget {
  const FilePreviewFooter({
    super.key,
    required this.fileName,
    this.localPath,
    this.remoteUrl,
    this.contentType = '',
    this.caption,
    required this.onOpen,
  });

  final String fileName;
  final String? localPath;
  final String? remoteUrl;
  final String contentType;
  final String? caption;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final captionText = caption?.trim();
    final hasCaption = captionText != null && captionText.isNotEmpty;
    final hasDock =
        fileName.trim().isNotEmpty &&
        ImagePreviewDock.hasSource(localPath: localPath, remoteUrl: remoteUrl);
    if (!hasCaption && !hasDock) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasCaption)
          Material(
            color: ImagePreviewChrome.bar,
            child: _Caption(text: captionText),
          ),
        if (hasDock)
          ImagePreviewDockSlot(
            child: ImagePreviewDock(
              fileName: fileName,
              localPath: localPath,
              remoteUrl: remoteUrl,
              contentType: contentType,
              onOpen: onOpen,
            ),
          ),
      ],
    );
  }
}

class _Caption extends StatefulWidget {
  const _Caption({required this.text});

  final String text;

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Text(
          widget.text,
          maxLines: _open ? null : 2,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
