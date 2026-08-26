import 'package:flutter/material.dart';

import 'image_preview_top_bar.dart';
import 'image_preview_zoom.dart';
import 'media_preview_actions.dart';
import 'preview_image.dart';

export 'preview_image.dart';

/// Fullscreen pinch-zoom gallery — same UX as wall image preview.
Future<void> showImagePreview(
  BuildContext context, {
  required List<PreviewImage> images,
  required int initialIndex,
  bool allowRemoteFallback = true,
}) {
  if (images.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (ctx) => _ImagePreviewDialog(
      images: images,
      initialIndex: initialIndex,
      allowRemoteFallback: allowRemoteFallback,
    ),
  );
}

class _ImagePreviewDialog extends StatefulWidget {
  const _ImagePreviewDialog({
    required this.images,
    required this.initialIndex,
    required this.allowRemoteFallback,
  });

  final List<PreviewImage> images;
  final int initialIndex;
  final bool allowRemoteFallback;

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_index];
    final localPath = img.localPath;
    final hasBytes =
        (localPath != null && localPath.isNotEmpty) ||
        (widget.allowRemoteFallback && img.fileUrl.isNotEmpty);
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      // A Scaffold so the save/share confirmation lands *inside* the viewer —
      // a SnackBar addressed to the screen underneath would be drawn behind
      // this dialog and never seen.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _page,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final a = widget.images[i];
                  return ZoomablePreviewImage(
                    image: a,
                    allowRemoteFallback: widget.allowRemoteFallback,
                  );
                },
              ),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: ImagePreviewTopBar(
                  image: img,
                  index: _index,
                  total: widget.images.length,
                  allowRemoteFallback: widget.allowRemoteFallback,
                ),
              ),
              if (hasBytes)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: MediaPreviewCircleButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Share',
                    onTap: () => runMediaPreviewAction(
                      context,
                      MediaPreviewAction.share,
                      localPath: localPath,
                      remoteUrl: widget.allowRemoteFallback
                          ? img.fileUrl
                          : null,
                      fileName: img.fileName,
                    ),
                  ),
                ),
              // High-contrast B/W close — always bottom-right.
              Positioned(
                right: 16,
                bottom: 16,
                child: MediaPreviewCircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
