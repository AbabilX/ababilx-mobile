import 'package:flutter/material.dart';

import 'file_preview_footer.dart';
import 'file_preview_kind.dart';
import 'file_preview_open.dart';
import 'image_preview_chrome.dart';
import 'image_preview_top_bar.dart';

/// Office / sheet / zip / anything we cannot render in-app.
///
/// Same chrome as the photo viewer. Open hands the file to another app —
/// there is no Word/Excel engine here, and a fake page would be worse.
class FilePreviewDialog extends StatelessWidget {
  const FilePreviewDialog({
    super.key,
    required this.fileName,
    this.contentType = '',
    this.localPath,
    this.remoteUrl,
    this.detail,
    this.caption,
    this.sizeBytes = 0,
  });

  final String fileName;
  final String contentType;
  final String? localPath;
  final String? remoteUrl;
  final String? detail;
  final String? caption;
  final int sizeBytes;

  @override
  Widget build(BuildContext context) {
    final kind = FilePreviewKind.of(
      fileName: fileName,
      contentType: contentType,
    );
    final size = formatPreviewFileSize(sizeBytes);
    return Dialog.fullscreen(
      backgroundColor: ImagePreviewChrome.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                ImagePreviewTopBar(fileName: fileName, detail: detail),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(kind.icon, size: 72, color: Colors.white70),
                          const SizedBox(height: 20),
                          Text(
                            fileName,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            size.isEmpty ? kind.label : '${kind.label} · $size',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FilePreviewFooter(
                fileName: fileName,
                localPath: localPath,
                remoteUrl: remoteUrl,
                contentType: contentType,
                caption: caption,
                onOpen: () => openPreviewExternally(
                  context,
                  localPath: localPath,
                  remoteUrl: remoteUrl,
                  contentType: contentType,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
