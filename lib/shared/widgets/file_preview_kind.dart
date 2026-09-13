import 'preview_icon.dart';

/// What kind of file the document viewer is holding.
enum FilePreviewKind {
  pdf,
  word,
  sheet,
  slides,
  zip,
  other;

  static FilePreviewKind of({
    required String fileName,
    String contentType = '',
  }) {
    final ct = contentType.toLowerCase();
    final name = fileName.toLowerCase();
    if (ct == 'application/pdf' ||
        ct == 'application/x-pdf' ||
        name.endsWith('.pdf')) {
      return pdf;
    }
    if (ct.contains('word') ||
        ct.contains('msword') ||
        ct.contains('opendocument.text') ||
        RegExp(r'\.(docx?|rtf|odt)$').hasMatch(name)) {
      return word;
    }
    if (ct.contains('spreadsheet') ||
        ct.contains('excel') ||
        ct.contains('opendocument.spreadsheet') ||
        RegExp(r'\.(xlsx?|csv|ods)$').hasMatch(name)) {
      return sheet;
    }
    if (ct.contains('presentation') ||
        ct.contains('powerpoint') ||
        ct.contains('opendocument.presentation') ||
        RegExp(r'\.(pptx?|odp)$').hasMatch(name)) {
      return slides;
    }
    if (ct.contains('zip') ||
        ct.contains('tar') ||
        ct.contains('gzip') ||
        ct.contains('compress') ||
        RegExp(r'\.(zip|rar|7z|tar|gz)$').hasMatch(name)) {
      return zip;
    }
    return other;
  }

  String get label => switch (this) {
    pdf => 'PDF',
    word => 'Document',
    sheet => 'Spreadsheet',
    slides => 'Presentation',
    zip => 'Archive',
    other => 'File',
  };

  PreviewGlyph get icon => switch (this) {
    pdf => PreviewIcons.pdf,
    word => PreviewIcons.word,
    sheet => PreviewIcons.sheet,
    slides => PreviewIcons.slides,
    zip => PreviewIcons.zip,
    other => PreviewIcons.file,
  };
}

/// `12 KB`, `1.4 MB`. Zero stays hidden — the viewer then omits the line.
String formatPreviewFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
