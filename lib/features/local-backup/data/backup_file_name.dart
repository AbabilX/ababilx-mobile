/// `<username>-2026-09-27-170138.abxbackup` — the person's own handle, so the
/// file is recognisable in a file manager. Cosmetic only: whose backup it is
/// comes from the header's account id (Kotlin `BackupHeader`), because a
/// handle can change or be empty. The handle is `[a-z0-9._-]` already
/// (server NormalizeUsername); anything else is dropped anyway, and no handle
/// falls back to "ababilx".
String backupFileName(String username, DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  final safe = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  final base = safe.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  final stamp =
      '${at.year}-${two(at.month)}-${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
  return '${base.isEmpty ? 'ababilx' : base}-$stamp.abxbackup';
}
