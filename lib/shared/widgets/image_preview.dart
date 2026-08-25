import 'package:flutter/material.dart';

import 'image_preview_zoom.dart';
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
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
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
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      img.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                      ),
                    ),
                  ),
                  if (widget.images.length > 1) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${_index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // High-contrast B/W close — always bottom-right.
            Positioned(
              right: 16,
              bottom: 16,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.black, width: 1.5),
                ),
                elevation: 4,
                shadowColor: Colors.black54,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
