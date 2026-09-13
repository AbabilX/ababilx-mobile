import 'package:flutter/material.dart';

import 'image_preview_chrome.dart';
import 'media_preview_actions.dart';

/// Visible Save + Share — no overflow menu. The row is the dock; the parent
/// paints the dark bar so caption / rail can sit above it in chat.
class ImagePreviewDock extends StatelessWidget {
  const ImagePreviewDock({
    super.key,
    required this.fileName,
    this.localPath,
    this.remoteUrl,
    this.contentType = '',
  });

  final String fileName;
  final String? localPath;
  final String? remoteUrl;
  final String contentType;

  static bool hasSource({String? localPath, String? remoteUrl}) {
    return (localPath != null && localPath.isNotEmpty) ||
        (remoteUrl != null && remoteUrl.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasSource(localPath: localPath, remoteUrl: remoteUrl)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Row(
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

/// Wall / CRM wrapper: the dock sitting on Signal's dark bar.
class ImagePreviewDockBar extends StatelessWidget {
  const ImagePreviewDockBar({
    super.key,
    required this.fileName,
    this.localPath,
    this.remoteUrl,
  });

  final String fileName;
  final String? localPath;
  final String? remoteUrl;

  @override
  Widget build(BuildContext context) {
    final dock = ImagePreviewDock(
      fileName: fileName,
      localPath: localPath,
      remoteUrl: remoteUrl,
    );
    if (!ImagePreviewDock.hasSource(
      localPath: localPath,
      remoteUrl: remoteUrl,
    )) {
      return const SizedBox.shrink();
    }
    return Material(
      color: ImagePreviewChrome.bar,
      child: SafeArea(top: false, child: dock),
    );
  }
}
