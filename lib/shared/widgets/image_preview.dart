import 'package:flutter/material.dart';

import 'image_preview_chrome.dart';
import 'image_preview_dock.dart';
import 'image_preview_top_bar.dart';
import 'image_preview_zoom.dart';
import 'preview_chrome_controller.dart';
import 'preview_image.dart';

export 'preview_image.dart';

/// Fullscreen pinch-zoom gallery — Signal-Android chrome, same as chat.
Future<void> showImagePreview(
  BuildContext context, {
  required List<PreviewImage> images,
  required int initialIndex,
  bool allowRemoteFallback = true,
}) {
  if (images.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: ImagePreviewChrome.background,
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
  late final PreviewChrome _chrome;
  late int _index;
  final _turns = <int, int>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _page = PageController(initialPage: _index);
    _chrome = PreviewChrome(onChanged: () {
      if (mounted) setState(() {});
    })..reveal();
  }

  @override
  void dispose() {
    _chrome.dispose();
    _page.dispose();
    super.dispose();
  }

  void _rotate() {
    setState(() => _turns[_index] = ((_turns[_index] ?? 0) + 1) % 4);
    _chrome.reveal();
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_index];
    final localPath = img.localPath;
    final remoteUrl = widget.allowRemoteFallback ? img.fileUrl : null;
    return Dialog.fullscreen(
      backgroundColor: ImagePreviewChrome.background,
      // A Scaffold so the save/share confirmation lands *inside* the viewer —
      // a SnackBar addressed to the screen underneath would be drawn behind
      // this dialog and never seen.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: widget.images.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _chrome.reveal();
              },
              itemBuilder: (_, i) {
                final a = widget.images[i];
                return ZoomablePreviewImage(
                  image: a,
                  allowRemoteFallback: widget.allowRemoteFallback,
                  quarterTurns: _turns[i] ?? 0,
                  onTap: _chrome.toggle,
                  onPan: _chrome.onContentPan,
                );
              },
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ImagePreviewChrome.layer(
                visible: _chrome.visible,
                child: ImagePreviewTopBar(
                  fileName: img.fileName,
                  detail: widget.images.length > 1
                      ? '${_index + 1} / ${widget.images.length}'
                      : null,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ImagePreviewChrome.layer(
                visible: _chrome.visible,
                child: ImagePreviewDockBar(
                  fileName: img.fileName,
                  localPath: localPath,
                  remoteUrl: remoteUrl,
                  onRotate: _rotate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
