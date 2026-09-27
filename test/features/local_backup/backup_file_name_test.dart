import 'package:ababilx/features/local-backup/local_backup_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 9, 27, 17, 1, 38);

  test('the file carries the username and the moment it was made', () {
    expect(backupFileName('murad', at), 'murad-2026-09-27-170138.abxbackup');
    expect(
      backupFileName('Murad.Dev', at),
      'murad.dev-2026-09-27-170138.abxbackup',
    );
  });

  test('no handle, or nothing usable in it, falls back to ababilx', () {
    expect(backupFileName('', at), 'ababilx-2026-09-27-170138.abxbackup');
    expect(backupFileName('../', at), 'ababilx-2026-09-27-170138.abxbackup');
    expect(backupFileName('a/b', at), 'ab-2026-09-27-170138.abxbackup');
  });
}
