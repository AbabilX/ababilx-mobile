import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'file_preview_footer.dart';
import 'file_preview_open.dart';
import 'image_preview_chrome.dart';
import 'image_preview_top_bar.dart';
import 'pdf_document_source.dart';
import 'preview_chrome_controller.dart';

class PdfFullscreenDialog extends StatefulWidget {
  const PdfFullscreenDialog({
    super.key,
    required this.source,
    required this.fileName,
    this.detail,
    this.caption,
  });

  final PdfDocumentSource source;
  final String fileName;
  final String? detail;
  final String? caption;

  @override
  State<PdfFullscreenDialog> createState() => _PdfFullscreenDialogState();
}

class _PdfFullscreenDialogState extends State<PdfFullscreenDialog> {
  PdfControllerPinch? _controller;
  String? _error;
  late final PreviewChrome _chrome;

  String? get _localPath => widget.source.isLocal ? widget.source.value : null;
  String? get _remoteUrl => widget.source.isLocal ? null : widget.source.value;

  @override
  void initState() {
    super.initState();
    _chrome = PreviewChrome(
      onChanged: () {
        if (mounted) setState(() {});
      },
    )..reveal();
    _open();
  }

  Future<void> _open() async {
    try {
      final controller = PdfControllerPinch(document: widget.source.open());
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load PDF');
    }
  }

  @override
  void dispose() {
    _chrome.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: ImagePreviewChrome.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _chrome.onScroll,
              child: GestureDetector(
                onTap: _chrome.toggle,
                behavior: HitTestBehavior.opaque,
                child: _body(),
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
                  localPath: _localPath,
                  remoteUrl: _remoteUrl,
                  contentType: 'application/pdf',
                  caption: widget.caption,
                  onOpen: () {
                    _chrome.reveal();
                    openPreviewExternally(
                      context,
                      localPath: _localPath,
                      remoteUrl: _remoteUrl,
                      contentType: 'application/pdf',
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

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return ColoredBox(
      color: ImagePreviewChrome.background,
      child: PdfViewPinch(controller: controller),
    );
  }
}
