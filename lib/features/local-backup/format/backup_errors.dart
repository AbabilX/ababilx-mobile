/// Why a backup could not be read. Each maps to one sentence on screen, so a
/// person learns whether to pick another file, sign in to another account, or
/// try again — "restore failed" alone answers none of those.
sealed class BackupError implements Exception {
  const BackupError();

  /// Translation key for the on-screen sentence.
  String get messageKey;
}

/// Not an AbabilX backup at all, or one written by a newer app.
class BackupNotABackupError extends BackupError {
  const BackupNotABackupError();
  @override
  String get messageKey => 'local_backup_error_not_backup';
}

/// Written by a different account: the key check did not match.
class BackupWrongAccountError extends BackupError {
  const BackupWrongAccountError();
  @override
  String get messageKey => 'local_backup_error_wrong_account';
}

/// Stops before its END record: copied halfway, or the phone died mid-write.
class BackupIncompleteError extends BackupError {
  const BackupIncompleteError();
  @override
  String get messageKey => 'local_backup_error_incomplete';
}

/// A record failed its tag: bytes changed after writing.
class BackupDamagedError extends BackupError {
  const BackupDamagedError();
  @override
  String get messageKey => 'local_backup_error_damaged';
}

class BackupCancelledError extends BackupError {
  const BackupCancelledError();
  @override
  String get messageKey => 'local_backup_error_cancelled';
}
