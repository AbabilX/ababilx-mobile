import 'package:ababilx/features/local-backup/data/backup_schedule.dart';
import 'package:ababilx/features/local-backup/data/local_backup_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const at9pm = 21 * 60;
  int ms(DateTime t) => t.millisecondsSinceEpoch;

  group('isBackupDue', () {
    bool due(DateTime? last, DateTime now, [int minute = at9pm]) => isBackupDue(
      lastMs: last == null ? null : ms(last),
      now: now,
      minuteOfDay: minute,
    );

    test('a phone with no backup yet does not wait for the time', () {
      expect(due(null, DateTime(2026, 10, 30, 10)), isTrue);
    });

    test('runs once the picked time has passed since the last backup', () {
      final last = DateTime(2026, 10, 29, 21, 30);
      expect(due(last, DateTime(2026, 10, 30, 20, 59)), isFalse);
      expect(due(last, DateTime(2026, 10, 30, 21)), isTrue);
    });

    test('never twice in one daily slot', () {
      final last = DateTime(2026, 10, 30, 21, 5);
      expect(due(last, DateTime(2026, 10, 30, 23)), isFalse);
      expect(due(last, DateTime(2026, 10, 31, 9)), isFalse);
      expect(due(last, DateTime(2026, 10, 31, 21)), isTrue);
    });

    test('a morning open catches up on last night\'s missed slot', () {
      final last = DateTime(2026, 10, 28, 21, 5);
      expect(due(last, DateTime(2026, 10, 30, 8)), isTrue);
    });

    test('a slot crossing the month and midnight still counts', () {
      expect(
        due(DateTime(2026, 10, 31, 0, 30), DateTime(2026, 11, 1, 0, 10), 0),
        isTrue,
      );
    });

    test('moving the time later today makes today\'s slot due', () {
      final last = DateTime(2026, 10, 30, 10);
      expect(due(last, DateTime(2026, 10, 30, 20), 18 * 60), isTrue);
      expect(due(last, DateTime(2026, 10, 30, 20), 9 * 60), isFalse);
    });

    test('a last backup dated in the future cannot stop backups', () {
      expect(due(DateTime(2030, 1, 1), DateTime(2026, 10, 30, 10)), isTrue);
    });
  });

  test('nextBackupAt is today while the time is ahead, else tomorrow', () {
    expect(
      nextBackupAt(DateTime(2026, 10, 30, 20), at9pm),
      DateTime(2026, 10, 30, 21),
    );
    expect(
      nextBackupAt(DateTime(2026, 10, 30, 21), at9pm),
      DateTime(2026, 10, 31, 21),
    );
    expect(
      nextBackupAt(DateTime(2026, 10, 31, 22), at9pm),
      DateTime(2026, 11, 1, 21),
    );
  });

  group('settings', () {
    test('an account that never chose gets the default time', () {
      expect(
        LocalBackupSettings.initial(automatic: true).backupMinute,
        defaultBackupMinute,
      );
      expect(
        LocalBackupSettings.fromStored({
          'auto': true,
          'enabled': true,
        }, automatic: true).backupMinute,
        defaultBackupMinute,
      );
    });

    test('a stored time that makes no sense falls back to the default', () {
      for (final bad in <Object?>[-1, 1440, 99999, 'noon', null, 1.5]) {
        expect(
          LocalBackupSettings.fromJson({'backup_minute': bad}).backupMinute,
          defaultBackupMinute,
          reason: '$bad',
        );
      }
    });

    test('copyWith keeps the time and can change it', () {
      const base = LocalBackupSettings(backupMinute: 600);
      expect(base.copyWith(enabled: true).backupMinute, 600);
      expect(base.copyWith(backupMinute: 615).backupMinute, 615);
    });

    test('the picked time survives the store, per account', () async {
      SharedPreferences.setMockInitialValues({});
      const store = LocalBackupSettingsStore();
      await store.write('a', const LocalBackupSettings(backupMinute: at9pm));
      expect((await store.read('a')).backupMinute, at9pm);
      expect((await store.read('b')).backupMinute, defaultBackupMinute);
    });
  });
}
