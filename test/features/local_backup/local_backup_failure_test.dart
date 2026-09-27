import 'package:ababilx/features/local-backup/data/local_backup_failure.dart';
import 'package:ababilx/features/local-backup/format/backup_errors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a media folder refusing the file gets its own sentence', () {
    expect(
      localBackupFailureKey(PlatformException(code: 'folder_refused')),
      'local_backup_error_folder_refused',
    );
    expect(
      localBackupFailureKey(PlatformException(code: 'local_backup_failed')),
      'local_backup_error_folder_io',
    );
    expect(
      localBackupFailureKey(const BackupWrongAccountError()),
      'local_backup_error_wrong_account',
    );
    expect(
      localBackupFailureKey(LocalBackupFailure.locked),
      'local_backup_error_locked',
    );
    expect(
      localBackupFailureKey(StateError('x')),
      'local_backup_error_generic',
    );
    // A plugin's error is not a folder problem.
    expect(
      localBackupFailureKey(PlatformException(code: 'CAUGHT_ERROR')),
      'local_backup_error_generic',
    );
    // A plugin's error is not a folder problem.
    expect(
      localBackupFailureKey(PlatformException(code: 'CAUGHT_ERROR')),
      'local_backup_error_generic',
    );
  });
}
