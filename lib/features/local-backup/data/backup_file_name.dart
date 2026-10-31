/// `AbabilX-murad-2026-09-27_17-01-38.abxbackup` — the app, the person's own
/// handle and the moment it was made, so a file manager says what the file
/// is and when without opening it. The date is year-month-day, so the files
/// sort by age, and the time is spelled out (17-01-38, not 170138).
///
/// Cosmetic only: whose backup it is comes from the header's account id
/// (Kotlin `BackupHeader`), because a handle can change or be empty. The
/// handle is `[a-z0-9._-]` already (server NormalizeUsername); anything else
/// is dropped anyway, and no handle leaves just the app and the date.
///
/// [customName] is what the person chose instead of the app and handle. The
/// moment always stays: two backups under one name would otherwise replace
/// each other, and the newest two must both survive.
String backupFileName(String username, DateTime at, {String customName = ''}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final safe = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  final handle = safe.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  final stamp =
      '${at.year}-${two(at.month)}-${two(at.day)}_'
      '${two(at.hour)}-${two(at.minute)}-${two(at.second)}';
  final custom = cleanBackupName(customName);
  if (custom.isNotEmpty) return '$custom-$stamp.abxbackup';
  return handle.isEmpty
      ? 'AbabilX-$stamp.abxbackup'
      : 'AbabilX-$handle-$stamp.abxbackup';
}

const backupNameMaxLength = 40;

final _notInName = RegExp(r'[^\p{L}\p{M}\p{N} ._-]', unicode: true);
final _edges = RegExp(r'^[ ._-]+|[ ._-]+$');

/// A typed name made safe to be one file's name in any folder: letters and
/// digits of any script, space, dot, dash, underscore. Slashes, control and
/// bidi characters are dropped, so it cannot leave the folder or read as
/// another file type; no leading dot, so it is never hidden.
String cleanBackupName(String typed) {
  final kept = typed
      .replaceAll(_notInName, '')
      .replaceAll(RegExp(r' +'), ' ')
      .replaceAll(_edges, '');
  if (kept.runes.length <= backupNameMaxLength) return kept;
  return String.fromCharCodes(
    kept.runes.take(backupNameMaxLength),
  ).replaceAll(_edges, '');
}
