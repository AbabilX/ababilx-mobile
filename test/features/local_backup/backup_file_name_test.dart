import 'package:ababilx/features/local-backup/local_backup_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 9, 27, 17, 1, 38);

  test('the file carries the app, the username and a readable moment', () {
    expect(
      backupFileName('murad', at),
      'AbabilX-murad-2026-09-27_17-01-38.abxbackup',
    );
    expect(
      backupFileName('Murad.Dev', at),
      'AbabilX-murad.dev-2026-09-27_17-01-38.abxbackup',
    );
  });

  test('no handle, or nothing usable in it, leaves the app and the date', () {
    expect(backupFileName('', at), 'AbabilX-2026-09-27_17-01-38.abxbackup');
    expect(backupFileName('../', at), 'AbabilX-2026-09-27_17-01-38.abxbackup');
    expect(
      backupFileName('a/b', at),
      'AbabilX-ab-2026-09-27_17-01-38.abxbackup',
    );
  });

  test('names sort by age', () {
    final older = backupFileName('murad', DateTime(2026, 9, 27, 9, 5, 1));
    final newer = backupFileName('murad', DateTime(2026, 10, 2, 8, 0, 0));
    expect(older.compareTo(newer), lessThan(0));
  });
}
