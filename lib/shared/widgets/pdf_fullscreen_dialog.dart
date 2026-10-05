import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'file_preview_footer.dart';
import 'file_preview_open.dart';
import 'image_preview_chrome.dart';
import 'image_preview_top_bar.dart';
import 'pdf_document_source.dart';
import 'pdf_print.dart';
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
  Uint8List? _bytes;
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
    if (!widget.source.isLocal) _download();
  }

  Future<void> _download() async {
    try {
      final bytes = await fetchPdfBytes(widget.source.value);
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load PDF');
    }
  }

  @override
  void dispose() {
    _chrome.dispose();
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
            _body(),
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
                  onPrint: () {
                    _chrome.reveal();
                    printPdf(
                      context,
                      source: widget.source,
                      fileName: widget.fileName,
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

  /// pdfium draws the pages: pinch / double-tap zoom, lazy per-page render and
  /// a real text layer, so long-press selects and copies text.
  PdfViewerParams get _params => PdfViewerParams(
    backgroundColor: ImagePreviewChrome.background,
    margin: 8,
    // Per-frame cost: a blurred shadow under every page, form/annotation
    // layers nobody edits here, and a render scale past what a phone shows.
    pageDropShadow: null,
    annotationRenderingMode: PdfAnnotationRenderingMode.none,
    verticalCacheExtent: 2,
    // pdfrx default (0.0000135) stops a fling far sooner than a phone's own
    // lists; lower friction = longer glide, closer to native scroll feel.
    interactionEndFrictionCoefficient: 0.000004,
    getPageRenderingScale: (context, page, controller, estimated) =>
        estimated.clamp(0.1, 3.0),
    textSelectionParams: const PdfTextSelectionParams(),
    onGeneralTap: (context, controller, details) {
      if (details.type != PdfViewerGeneralTapType.tap) return false;
      if (details.tapOn == PdfViewerPart.selectedText) return false;
      _chrome.toggle();
      return true;
    },
    errorBannerBuilder: (context, error, stack, ref) => const Center(
      child: Text(
        'Could not load PDF',
        style: TextStyle(color: Colors.white70),
      ),
    ),
  );

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (widget.source.isLocal) {
      return PdfViewer.file(widget.source.value, params: _params);
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return PdfViewer.data(
      bytes,
      sourceName: widget.source.cacheKey,
      params: _params,
    );
  }
}
