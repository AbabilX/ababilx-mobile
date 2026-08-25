import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdfx/pdfx.dart';

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

Future<Uint8List> fetchPdfBytes(String url) async {
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
  return Uint8List.fromList(data);
}
