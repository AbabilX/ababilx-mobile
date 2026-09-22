import 'package:flutter/services.dart';

import 'ghost_blobs.dart';

/// An open PDF held by the native renderer (`GhostPdfDocuments.kt`).
class GhostPdfDoc {
  const GhostPdfDoc(this.id, this.pages);
  final String id;
  final int pages;
}

/// Renders a Ghost Chat PDF in-app, page by page, entirely from memory.
///
/// Android only (API 26+): the bytes sit in `GhostBlobProvider` and Android's
/// `PdfRenderer` reads them through a RAM-backed descriptor. pdfx is not used
/// because it writes the document to the cache directory. [open] returns null
/// wherever that is not possible, and the caller says the file cannot be shown.
abstract final class GhostPdf {
  static const _channel = MethodChannel('com.ababilx.app/ghost_blob');

  static Future<GhostPdfDoc?> open(String key, Uint8List bytes) async {
    final uri = await GhostBlobs.put(
      'document.pdf',
      'application/pdf',
      bytes,
      key: key,
    );
    if (uri == null) return null;
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>('pdfOpen', {
        'uri': uri,
      });
      final id = reply?['id'], pages = reply?['pages'];
      if (id is! String || pages is! int || pages <= 0) return null;
      return GhostPdfDoc(id, pages);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// One page as PNG bytes, [width] pixels wide. Null if it could not render.
  static Future<Uint8List?> page(GhostPdfDoc doc, int index, int width) async {
    try {
      return await _channel.invokeMethod<Uint8List>('pdfPage', {
        'id': doc.id,
        'index': index,
        'width': width,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> close(GhostPdfDoc doc) async {
    try {
      await _channel.invokeMethod<void>('pdfClose', {'id': doc.id});
    } on PlatformException {
      // The burn closes everything anyway.
    } on MissingPluginException {
      // Same.
    }
  }
}
