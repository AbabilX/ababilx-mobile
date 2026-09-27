import 'package:intl/intl.dart';

/// "48 MB", "512 KB" — one decimal under ten so a small backup is not "0 MB".
String backupSizeLabel(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  String fixed(double v) =>
      v < 10 ? v.toStringAsFixed(1) : v.round().toString();
  if (bytes >= gb) return '${fixed(bytes / gb)} GB';
  if (bytes >= mb) return '${fixed(bytes / mb)} MB';
  if (bytes >= kb) return '${fixed(bytes / kb)} KB';
  return '$bytes B';
}

/// "Today 3:12 AM", "Yesterday 3:12 AM", "27 Sep 2026, 3:12 AM". A date and
/// not "5 hours ago": the question on this screen is "is last night's there".
String backupTimeLabel(
  DateTime at, {
  required DateTime now,
  required String today,
  required String yesterday,
}) {
  final time = DateFormat.jm().format(at);
  final day = DateTime(at.year, at.month, at.day);
  final days = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (days == 0) return '$today $time';
  if (days == 1) return '$yesterday $time';
  return '${DateFormat('d MMM y').format(at)}, $time';
}
