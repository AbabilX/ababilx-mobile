import 'package:flutter/material.dart';

import 'file_preview_footer.dart';
import 'file_preview_kind.dart';
import 'file_preview_open.dart';
import 'image_preview_chrome.dart';
import 'image_preview_top_bar.dart';
import 'preview_chrome_controller.dart';
import 'preview_icon.dart';

/// Office / sheet / zip / anything we cannot render in-app.
///
/// Same chrome as the photo viewer. Open hands the file to another app —
/// there is no Word/Excel engine here, and a fake page would be worse.
class FilePreviewDialog extends StatefulWidget {
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
  State<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<FilePreviewDialog> {
  late final PreviewChrome _chrome;

  @override
  void initState() {
    super.initState();
    _chrome = PreviewChrome(
      onChanged: () {
        if (mounted) setState(() {});
      },
    )..reveal();
  }

  @override
  void dispose() {
    _chrome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = FilePreviewKind.of(
      fileName: widget.fileName,
      contentType: widget.contentType,
    );
    final size = formatPreviewFileSize(widget.sizeBytes);
    return Dialog.fullscreen(
      backgroundColor: ImagePreviewChrome.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _chrome.toggle,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PreviewIcon(kind.icon, size: 72, color: Colors.white70),
                      const SizedBox(height: 20),
                      Text(
                        widget.fileName,
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
            Align(
              alignment: Alignment.topCenter,
              child: ImagePreviewChrome.layer(
                visible: _chrome.visible,
                child: ImagePreviewTopBar(
                  fileName: widget.fileName,
                  detail: widget.detail,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ImagePreviewChrome.layer(
                visible: _chrome.visible,
                child: FilePreviewFooter(
                  fileName: widget.fileName,
                  localPath: widget.localPath,
                  remoteUrl: widget.remoteUrl,
                  contentType: widget.contentType,
                  caption: widget.caption,
                  onOpen: () {
                    _chrome.reveal();
                    openPreviewExternally(
                      context,
                      localPath: widget.localPath,
                      remoteUrl: widget.remoteUrl,
                      contentType: widget.contentType,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
