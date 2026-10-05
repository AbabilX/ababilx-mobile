import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_document_source.dart';
import 'preview_icon.dart';

const double _thumbWidth = 420;
final PdfRenderGate _gate = PdfRenderGate(2);

class PdfPreviewThumb extends StatefulWidget {
  const PdfPreviewThumb({super.key, required this.source, this.height});

  final PdfDocumentSource source;

  /// Null means fill the parent — the card already owns the height.
  final double? height;

  @override
  State<PdfPreviewThumb> createState() => _PdfPreviewThumbState();
}

class _PdfPreviewThumbState extends State<PdfPreviewThumb> {
  ui.Image? _thumb;
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
      final bytes = await _gate.run(_renderFirstPage);
      if (bytes != null) PdfThumbCache.put(key, bytes);
      if (mounted) {
        setState(() {
          _thumb = bytes;
          _done = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _done = true);
    }
  }

  /// A card is ~300dp wide; 560px is sharp enough and a JPEG of it encodes in
  /// a fraction of the time a full-size PNG took.
  Future<ui.Image?> _renderFirstPage() async {
    final doc = await widget.source.open();
    try {
      final page = doc.pages.first;
      final height = _thumbWidth * page.height / page.width;
      final image = await page.render(
        fullWidth: _thumbWidth,
        fullHeight: height,
        backgroundColor: 0xFFFFFFFF,
      );
      if (image == null) return null;
      try {
        return await image.createImage();
      } finally {
        image.dispose();
      }
    } finally {
      await doc.dispose();
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
          ? RawImage(
              image: _thumb!,
              fit: BoxFit.cover,
              alignment: Alignment.topLeft,
              width: double.infinity,
              height: double.infinity,
            )
          : PreviewIcon(
              PreviewIcons.pdf,
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
  static final Map<String, ui.Image> _map = {};

  static ui.Image? get(String key) => _map[key];

  static void put(String key, ui.Image bytes) {
    if (_map.length > 24) _map.remove(_map.keys.first);
    _map[key] = bytes;
  }
}
