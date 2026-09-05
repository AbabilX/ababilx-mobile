/// Byte counts as a person reads them — `842 KB`, `12.4 MB`, `1.2 GB`.
///
/// Base 1024, because the numbers this labels come from file lengths rather
/// than from a carrier's data plan, and one decimal at most: a storage screen
/// is scanned for scale, not audited.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final rounded = value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}
