import 'dart:io';

import 'package:flutter/material.dart';

import 'preview_icon.dart';
import 'preview_image.dart';

class ZoomablePreviewImage extends StatefulWidget {
  const ZoomablePreviewImage({
    super.key,
    required this.image,
    required this.allowRemoteFallback,
    this.quarterTurns = 0,
    this.onTap,
    this.onPan,
  });

  final PreviewImage image;
  final bool allowRemoteFallback;

  /// View-only 90° steps. Save / Share still write the original file.
  final int quarterTurns;

  /// Single tap — Signal toggles the chrome. Double-tap still zooms.
  final VoidCallback? onTap;

  /// Pinch or drag — chrome hides so the photo owns the screen.
  final VoidCallback? onPan;

  @override
  State<ZoomablePreviewImage> createState() => _ZoomablePreviewImageState();
}

class _ZoomablePreviewImageState extends State<ZoomablePreviewImage>
    with AutomaticKeepAliveClientMixin {
  final _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(ZoomablePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quarterTurns != widget.quarterTurns) {
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final pos = _doubleTapDetails?.localPosition;
    if (pos == null) return;
    if (_transform.value.getMaxScaleOnAxis() > 1.05) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-pos.dx * (scale - 1), -pos.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        clipBehavior: Clip.none,
        onInteractionUpdate: (details) {
          if (details.scale != 1 || details.focalPointDelta.distance > 1.5) {
            widget.onPan?.call();
          }
        },
        child: AnimatedRotation(
          turns: widget.quarterTurns / 4,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: SizedBox.expand(child: _image()),
        ),
      ),
    );
  }

  Widget _image() {
    final path = widget.image.localPath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _error(),
      );
    }
    if (!widget.allowRemoteFallback) return _error();
    return Image.network(
      widget.image.fileUrl,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (_, _, _) => _error(),
    );
  }

  Widget _error() => const PreviewIcon(
    PreviewIcons.brokenImage,
    color: Colors.white54,
    size: 48,
  );
}
