import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfDocumentSource {
  const PdfDocumentSource.url(this.value) : isLocal = false;
  const PdfDocumentSource.file(this.value) : isLocal = true;

  final String value;
  final bool isLocal;

  String get cacheKey => '${isLocal ? 'file' : 'url'}:$value';

  Future<PdfDocument> open() async {
    if (isLocal) return PdfDocument.openFile(value);
    return PdfDocument.openData(await fetchPdfBytes(value));
  }
}

/// Downloaded PDFs, newest last. The card thumbnail and the fullscreen viewer
/// ask for the same url back to back, and each used to pull the whole file.
final Map<String, Uint8List> _pdfBytes = {};
final Map<String, Future<Uint8List>> _pdfInFlight = {};
const _pdfBytesBudget = 24 * 1024 * 1024;

Future<Uint8List> fetchPdfBytes(String url) {
  final hit = _pdfBytes.remove(url);
  if (hit != null) {
    _pdfBytes[url] = hit;
    return Future.value(hit);
  }
  return _pdfInFlight[url] ??= _download(
    url,
  ).whenComplete(() => _pdfInFlight.remove(url));
}

Future<Uint8List> _download(String url) async {
  final response = await Dio().get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: true,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 400,
    ),
  );
  final data = response.data;
  if (data == null || data.isEmpty) throw StateError('Empty PDF response');
  final bytes = data is Uint8List ? data : Uint8List.fromList(data);
  _remember(url, bytes);
  return bytes;
}

void _remember(String url, Uint8List bytes) {
  if (bytes.length > _pdfBytesBudget) return;
  _pdfBytes[url] = bytes;
  var total = _pdfBytes.values.fold<int>(0, (sum, b) => sum + b.length);
  while (total > _pdfBytesBudget && _pdfBytes.length > 1) {
    total -= _pdfBytes.remove(_pdfBytes.keys.first)!.length;
  }
}

/// Runs at most [limit] jobs at once. A chat screen full of PDFs would
/// otherwise open every document and render every page 1 in the same frame.
class PdfRenderGate {
  PdfRenderGate(this.limit);
  final int limit;
  int _running = 0;
  final List<Completer<void>> _waiting = [];

  Future<T> run<T>(Future<T> Function() job) async {
    if (_running >= limit) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _running++;
    }
    try {
      return await job();
    } finally {
      if (_waiting.isEmpty) {
        _running--;
      } else {
        _waiting.removeAt(0).complete();
      }
    }
  }
}
