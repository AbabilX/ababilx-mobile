import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_document_source.dart';

class PdfPreviewThumb extends StatefulWidget {
  const PdfPreviewThumb({super.key, required this.source, this.height});

  final PdfDocumentSource source;

  /// Null means fill the parent — the card already owns the height.
  final double? height;

  @override
  State<PdfPreviewThumb> createState() => _PdfPreviewThumbState();
}

class _PdfPreviewThumbState extends State<PdfPreviewThumb> {
  Uint8List? _thumb;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PdfPreviewThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.cacheKey != widget.source.cacheKey) {
      _thumb = null;
      _done = false;
      _load();
    }
  }

  Future<void> _load() async {
    final key = widget.source.cacheKey;
    final cached = PdfThumbCache.get(key);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _thumb = cached;
          _done = true;
        });
      }
      return;
    }
    try {
      final doc = await widget.source.open();
      final page = await doc.getPage(1);
      try {
        final image = await page.render(
          width: page.width * 1.2,
          height: page.height * 1.2,
          format: PdfPageImageFormat.png,
        );
        final bytes = image?.bytes;
        if (bytes != null) PdfThumbCache.put(key, bytes);
        if (mounted) {
          setState(() {
            _thumb = bytes;
            _done = true;
          });
        }
      } finally {
        await page.close();
        await doc.close();
      }
    } catch (_) {
      if (mounted) setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final plate = ColoredBox(
      color: colors.surface,
      child: !_done
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _thumb != null
          ? Image.memory(
              _thumb!,
              fit: BoxFit.cover,
              alignment: Alignment.topLeft,
              width: double.infinity,
              height: double.infinity,
            )
          : Icon(
              Icons.picture_as_pdf_outlined,
              size: 40,
              color: colors.onSurfaceVariant,
            ),
    );
    if (widget.height == null) return SizedBox.expand(child: plate);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: plate,
    );
  }
}

class PdfThumbCache {
  PdfThumbCache._();
  static final Map<String, Uint8List> _map = {};

  static Uint8List? get(String key) => _map[key];

  static void put(String key, Uint8List bytes) {
    if (_map.length > 40) _map.remove(_map.keys.first);
    _map[key] = bytes;
  }
}
