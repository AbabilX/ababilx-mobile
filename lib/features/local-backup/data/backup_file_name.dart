/// `AbabilX-murad-2026-09-27_17-01-38.abxbackup` — the app, the person's own
/// handle and the moment it was made, so a file manager says what the file
/// is and when without opening it. The date is year-month-day, so the files
/// sort by age, and the time is spelled out (17-01-38, not 170138).
///
/// Cosmetic only: whose backup it is comes from the header's account id
/// (Kotlin `BackupHeader`), because a handle can change or be empty. The
/// handle is `[a-z0-9._-]` already (server NormalizeUsername); anything else
/// is dropped anyway, and no handle leaves just the app and the date.
String backupFileName(String username, DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  final safe = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  final handle = safe.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  final stamp =
      '${at.year}-${two(at.month)}-${two(at.day)}_'
      '${two(at.hour)}-${two(at.minute)}-${two(at.second)}';
  return handle.isEmpty
      ? 'AbabilX-$stamp.abxbackup'
      : 'AbabilX-$handle-$stamp.abxbackup';
}
