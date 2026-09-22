import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../native/ghost_pdf.dart';
import '../providers/ghost_state.dart';
import '../widgets/ghost_labels.dart';
import 'ghost_viewer_guard.dart';

Future<void> showGhostPdf(BuildContext context, GhostItem item) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GhostPdfViewer(id: item.id, bytes: item.bytes!),
      ),
    );

/// A view-only Ghost PDF: pages rendered natively from memory
/// ([GhostPdf]), shown here, never written anywhere. Rendered pages are held
/// in this screen only and zeroed when it closes.
class GhostPdfViewer extends ConsumerStatefulWidget {
  const GhostPdfViewer({super.key, required this.id, required this.bytes});

  final String id;
  final Uint8List bytes;

  @override
  ConsumerState<GhostPdfViewer> createState() => _GhostPdfViewerState();
}

class _GhostPdfViewerState extends ConsumerState<GhostPdfViewer> {
  GhostPdfDoc? _doc;
  bool _failed = false;
  final _pages = <int, Future<Uint8List?>>{};
  final _rendered = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    GhostPdf.open(widget.id, widget.bytes).then((doc) {
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
    final item = watchGhostViewerItem(context, ref, widget.id);
    final doc = _doc;
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(
          item?.fileName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: item == null
          ? const SizedBox.expand()
          : _failed
          ? Center(child: Text(ghostText(ref, 'ghost_err_cannot_show')))
          : doc == null
          ? const Center(child: CircularProgressIndicator())
          // Pinch zooms; one finger stays with the list so pages scroll.
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
