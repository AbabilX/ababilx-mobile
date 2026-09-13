import 'package:flutter/material.dart';

import 'image_preview_chrome.dart';
import 'media_preview_actions.dart';

/// Floating capsule: Save · Rotate/Mute · Share. No overflow, no full-width bar.
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

  static bool hasSource({String? localPath, String? remoteUrl}) {
    return (localPath != null && localPath.isNotEmpty) ||
        (remoteUrl != null && remoteUrl.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasSource(localPath: localPath, remoteUrl: remoteUrl)) {
      return const SizedBox.shrink();
    }
    return Material(
      color: ImagePreviewChrome.capsule,
      elevation: 8,
      shadowColor: Colors.black54,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DockAction(
              icon: Icons.save_alt_rounded,
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
                icon: Icons.rotate_right_rounded,
                label: 'Rotate',
                onTap: onRotate!,
              ),
            if (onMute != null)
              _DockAction(
                icon: muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                label: muted ? 'Unmute' : 'Mute',
                onTap: onMute!,
              ),
            _DockAction(
              icon: Icons.ios_share_rounded,
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

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: SizedBox(
        width: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
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
      ),
    );
  }
}

/// Wall / CRM: capsule over the photo, not a full-width strip.
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          child: ImagePreviewDock(
            fileName: fileName,
            localPath: localPath,
            remoteUrl: remoteUrl,
            onRotate: onRotate,
          ),
        ),
      ),
    );
  }
}
