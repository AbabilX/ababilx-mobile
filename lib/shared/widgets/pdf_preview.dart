import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web parity ([pdf-preview.tsx]): in-app PDF dialog with pinch zoom,
/// open-external + download actions. Also first-page thumbnail cards.
Future<void> showPdfPreview(
  BuildContext context, {
  required String fileUrl,
  required String fileName,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (_) => _PdfPreviewDialog(fileUrl: fileUrl, fileName: fileName),
  );
}

class _PdfPreviewDialog extends StatefulWidget {
  const _PdfPreviewDialog({required this.fileUrl, required this.fileName});

  final String fileUrl;
  final String fileName;

  @override
  State<_PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<_PdfPreviewDialog> {
  PdfControllerPinch? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final bytes = await fetchPdfBytes(widget.fileUrl);
      if (!mounted) return;
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load PDF';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.fileUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF externally')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: Colors.black12,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _openExternal,
                                child: const Text('Open externally'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : PdfViewPinch(controller: _controller!),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _openExternal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open externally'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline PDF card — first-page thumb (like web feed) + tap opens viewer.
class PdfPreviewCard extends StatefulWidget {
  const PdfPreviewCard({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.hideFileName = false,
    this.height = 260,
  });

  final String fileUrl;
  final String fileName;
  final bool hideFileName;
  final double height;

  @override
  State<PdfPreviewCard> createState() => _PdfPreviewCardState();
}

class _PdfPreviewCardState extends State<PdfPreviewCard> {
  Uint8List? _thumb;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  @override
  void didUpdateWidget(covariant PdfPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileUrl != widget.fileUrl) {
      _thumb = null;
      _loading = true;
      _failed = false;
      _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    try {
      final cached = PdfThumbCache.get(widget.fileUrl);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _thumb = cached;
          _loading = false;
        });
        return;
      }

      final bytes = await fetchPdfBytes(widget.fileUrl);
      final doc = await PdfDocument.openData(bytes);
      final page = await doc.getPage(1);
      try {
        final rendered = await page.render(
          width: page.width * 1.2,
          height: page.height * 1.2,
          format: PdfPageImageFormat.png,
        );
        final png = rendered?.bytes;
        if (png != null) PdfThumbCache.put(widget.fileUrl, png);
        if (!mounted) return;
        setState(() {
          _thumb = png;
          _loading = false;
          _failed = png == null;
        });
      } finally {
        await page.close();
        await doc.close();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: widget.hideFileName ? null : BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showPdfPreview(
          context,
          fileUrl: widget.fileUrl,
          fileName: widget.fileName,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.hideFileName)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC1C24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: widget.height,
              width: double.infinity,
              child: ColoredBox(
                color: Colors.white,
                child: _loading
                    ? Center(
                        child: Text(
                          'Loading preview...',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _thumb != null
                    ? Image.memory(
                        _thumb!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topLeft,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Center(
                        child: Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 40,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
              ),
            ),
            if (_failed && !widget.hideFileName)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'Tap to open PDF',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple in-memory first-page PNG cache (session).
class PdfThumbCache {
  PdfThumbCache._();
  static final Map<String, Uint8List> _map = {};

  static Uint8List? get(String url) => _map[url];

  static void put(String url, Uint8List bytes) {
    if (_map.length > 40) _map.remove(_map.keys.first);
    _map[url] = bytes;
  }
}

Future<Uint8List> fetchPdfBytes(String url) async {
  final response = await Dio().get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: true,
      validateStatus: (s) => s != null && s >= 200 && s < 400,
    ),
  );
  final data = response.data;
  if (data == null || data.isEmpty) {
    throw StateError('Empty PDF response');
  }
  return Uint8List.fromList(data);
}
