/// Human-readable byte count for the download badge — `842 KB`, `12.4 MB`.
String attachmentSizeLabel(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  if (mb < 100) return '${mb.toStringAsFixed(1)} MB';
  return '${mb.round()} MB';
}
