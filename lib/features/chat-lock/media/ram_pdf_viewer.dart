import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../ghost/native/ghost_pdf.dart';

/// A locked chat's PDF, rendered page by page from memory by Android's
/// PdfRenderer (through Ghost Chat's native half). pdfx is not used: it
/// writes the document into the cache directory. Rendered pages live in
/// this screen only and are zeroed when it closes.
class RamPdfViewer extends StatefulWidget {
  const RamPdfViewer({
    super.key,
    required this.blobKey,
    required this.bytes,
    required this.fileName,
    required this.cannotShow,
  });

  final String blobKey;
  final Uint8List bytes;
  final String fileName;
  final String cannotShow;

  @override
  State<RamPdfViewer> createState() => _RamPdfViewerState();
}

class _RamPdfViewerState extends State<RamPdfViewer> {
  GhostPdfDoc? _doc;
  bool _failed = false;
  final _pages = <int, Future<Uint8List?>>{};
  final _rendered = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    GhostPdf.open(widget.blobKey, widget.bytes).then((doc) {
      if (!mounted) {
        if (doc != null) GhostPdf.close(doc);
        return;
      }
      setState(() {
        _doc = doc;
        _failed = doc == null;
      });
    });
  }

  @override
  void dispose() {
    final doc = _doc;
    if (doc != null) GhostPdf.close(doc);
    for (final png in _rendered) {
      png.fillRange(0, png.length, 0);
    }
    super.dispose();
  }

  Future<Uint8List?> _page(GhostPdfDoc doc, int index, int width) =>
      _pages[index] ??= GhostPdf.page(doc, index, width).then((png) {
        if (png != null) _rendered.add(png);
        return png;
      });

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final colors = Theme.of(context).colorScheme;
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return Scaffold(
      backgroundColor: colors.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _failed
          ? Center(child: Text(widget.cannotShow))
          : doc == null
          ? const Center(child: CircularProgressIndicator())
          : InteractiveViewer(
              panEnabled: false,
              maxScale: 4,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: doc.pages,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => FutureBuilder<Uint8List?>(
                  future: _page(doc, index, width),
                  builder: (context, snap) {
                    final png = snap.data;
                    if (png != null) {
                      return Image.memory(png, gaplessPlayback: true);
                    }
                    return AspectRatio(
                      aspectRatio: 1 / 1.414,
                      child: ColoredBox(
                        color: colors.surface,
                        child: snap.connectionState == ConnectionState.done
                            ? const Icon(Icons.broken_image_outlined)
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
