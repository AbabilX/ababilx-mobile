import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'pdf_document_source.dart';

/// Hands the PDF to the system print dialog. Nothing is rendered here; the OS
/// print service takes the bytes as they are.
Future<void> printPdf(
  BuildContext context, {
  required PdfDocumentSource source,
  required String fileName,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final bytes = source.isLocal
        ? await File(source.value).readAsBytes()
        : await fetchPdfBytes(source.value);
    await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('Could not print')));
  }
}
