import 'package:flutter/material.dart';

import 'image_preview_dock.dart';

/// Safe-area pad that pins the capsule to the bottom-center.
///
/// Do not wrap the dock in [Center]: under a full-screen [Align] that
/// expands, Center fills the viewer and an avatar/banner preview draws the
/// capsule in the middle of the photo. [Align.bottomCenter] keeps it on
/// the bottom edge and centered horizontally.
class ImagePreviewDockSlot extends StatelessWidget {
  const ImagePreviewDockSlot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }
}

/// Wall / CRM / profile: capsule over the photo, bottom-center.
class ImagePreviewDockBar extends StatelessWidget {
  const ImagePreviewDockBar({
    super.key,
    required this.fileName,
    this.localPath,
    this.remoteUrl,
    this.onRotate,
  });

  final String fileName;
  final String? localPath;
  final String? remoteUrl;
  final VoidCallback? onRotate;

  @override
  Widget build(BuildContext context) {
    if (!ImagePreviewDock.hasSource(
      localPath: localPath,
      remoteUrl: remoteUrl,
    )) {
      return const SizedBox.shrink();
    }
    return ImagePreviewDockSlot(
      child: ImagePreviewDock(
        fileName: fileName,
        localPath: localPath,
        remoteUrl: remoteUrl,
        onRotate: onRotate,
      ),
    );
  }
}
