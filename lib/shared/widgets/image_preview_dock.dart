import 'package:flutter/material.dart';

import '../media/media_save_lock.dart';
import 'image_preview_chrome.dart';
import 'media_preview_actions.dart';
import 'preview_icon.dart';

export 'image_preview_dock_bar.dart';

/// Floating capsule that hugs its actions — no fixed slot width.
class ImagePreviewDock extends StatelessWidget {
  const ImagePreviewDock({
    super.key,
    required this.fileName,
    this.localPath,
    this.remoteUrl,
    this.contentType = '',
    this.onRotate,
    this.onMute,
    this.muted = false,
    this.onOpen,
  });

  final String fileName;
  final String? localPath;
  final String? remoteUrl;
  final String contentType;

  /// View-only quarter turn. Null hides the control.
  final VoidCallback? onRotate;

  /// Video viewer. Null hides the control.
  final VoidCallback? onMute;
  final bool muted;

  /// Documents / PDF — open in another app. Null hides the control.
  final VoidCallback? onOpen;

  static bool hasSource({String? localPath, String? remoteUrl}) {
    return (localPath != null && localPath.isNotEmpty) ||
        (remoteUrl != null && remoteUrl.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasSource(localPath: localPath, remoteUrl: remoteUrl)) {
      return const SizedBox.shrink();
    }
    // A private group (MediaSaveLock) keeps its media in the app: no Save, no
    // Share. Rotate, mute and Open stay — they change nothing outside.
    return ValueListenableBuilder<int>(
      valueListenable: MediaSaveLock.listenable,
      builder: (context, _, _) => _capsule(context, !MediaSaveLock.held),
    );
  }

  Widget _capsule(BuildContext context, bool canExport) {
    if (!canExport && onRotate == null && onMute == null && onOpen == null) {
      return const SizedBox.shrink();
    }
    return Material(
      color: ImagePreviewChrome.capsule,
      elevation: 8,
      shadowColor: Colors.black54,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canExport)
              _DockAction(
                icon: PreviewIcons.save,
                label: 'Save',
                onTap: () => runMediaPreviewAction(
                  context,
                  MediaPreviewAction.save,
                  localPath: localPath,
                  remoteUrl: remoteUrl,
                  fileName: fileName,
                  contentType: contentType,
                ),
              ),
            if (onRotate != null)
              _DockAction(
                icon: PreviewIcons.rotate,
                label: 'Rotate',
                onTap: onRotate!,
              ),
            if (onMute != null)
              _DockAction(
                icon: muted ? PreviewIcons.mute : PreviewIcons.unmute,
                label: muted ? 'Unmute' : 'Mute',
                onTap: onMute!,
              ),
            if (onOpen != null)
              _DockAction(
                icon: PreviewIcons.open,
                label: 'Open',
                onTap: onOpen!,
              ),
            if (canExport)
              _DockAction(
                icon: PreviewIcons.share,
                label: 'Share',
                onTap: () => runMediaPreviewAction(
                  context,
                  MediaPreviewAction.share,
                  localPath: localPath,
                  remoteUrl: remoteUrl,
                  fileName: fileName,
                  contentType: contentType,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final PreviewGlyph icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PreviewIcon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
