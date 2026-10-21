/// `2026-10-21` for an ISO stamp, local time; the raw text when unparsable.
String importedDate(String iso) {
  final at = DateTime.tryParse(iso)?.toLocal();
  if (at == null) return iso;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)}';
}

/// `17:01` for an ISO stamp, local time.
String importedTime(String iso) {
  final at = DateTime.tryParse(iso)?.toLocal();
  if (at == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(at.hour)}:${two(at.minute)}';
}
