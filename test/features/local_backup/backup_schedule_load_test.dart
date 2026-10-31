import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ababilx/features/local-backup/auto/account_backup_dir.dart';
import 'package:ababilx/features/local-backup/data/backup_file_name.dart';
import 'package:ababilx/features/local-backup/data/backup_schedule.dart';
import 'package:ababilx/features/local-backup/data/local_backup_settings.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_automatic_support.dart';

/// Simulated users of the daily backup time and the backup file name. Seeded,
/// so a failure repeats. Run under different `TZ` values to cross clock
/// changes. Nothing here touches a server or a phone.
const _users = 1000;
const _diskUsers = 1000;

void main() {
  test('$_users users, four months each: one backup per slot, none missed', () {
    final random = Random(20261030);
    var backups = 0;
    var opens = 0;
    var longestWait = Duration.zero;
    for (var user = 0; user < _users; user++) {
      final minute = random.nextInt(24 * 60);
      var now = DateTime(
        2026,
        1,
        1,
      ).add(Duration(minutes: random.nextInt(1440)));
      final end = DateTime(2026, 11, 15);
      now = now.add(const Duration(days: 200));
      int? last;
      var ran = 0;
      while (now.isBefore(end)) {
        opens++;
        final next = nextBackupAt(now, minute);
        expect(next.isAfter(now), isTrue, reason: 'next $next, now $now');
        final wait = next.difference(now);
        if (wait > longestWait) longestWait = wait;

        final previous = last;
        final due = isBackupDue(
          lastMs: previous,
          now: now,
          minuteOfDay: minute,
        );
        if (previous != null) {
          // Worked out apart from the rule: did the time come round since?
          final since = DateTime.fromMillisecondsSinceEpoch(previous);
          final cameRound = !nextBackupAt(since, minute).isAfter(now);
          expect(due, cameRound, reason: 'minute=$minute last=$since now=$now');
        }
        if (due) {
          last = now.millisecondsSinceEpoch;
          ran++;
          expect(
            isBackupDue(lastMs: last, now: now, minuteOfDay: minute),
            isFalse,
            reason: 'ran twice at $now, minute=$minute',
          );
        }
        // Heavy users open it within minutes; some stay away for days.
        now = now.add(
          Duration(
            minutes: switch (random.nextInt(10)) {
              0 => 1 + random.nextInt(5 * 1440),
              < 4 => 1 + random.nextInt(600),
              _ => 1 + random.nextInt(90),
            },
          ),
        );
      }
      expect(ran, lessThanOrEqualTo(135), reason: 'minute=$minute');
      backups += ran;
    }
    expect(longestWait, lessThanOrEqualTo(const Duration(hours: 25)));
    // ignore: avoid_print
    print('LOAD schedule users=$_users opens=$opens backups=$backups');
  });

  test('$_users hostile names: always one safe file inside the folder', () {
    final random = Random(7);
    final dir = Directory.systemTemp.createTempSync('backup_names');
    addTearDown(() => dir.deleteSync(recursive: true));
    const pieces = [
      '../',
      '..\\',
      '/',
      '\\',
      '.',
      ' ',
      '-',
      '_',
      'a',
      'Z',
      '9',
      'ব',
      'ি',
      '\u0000',
      '\n',
      '\t',
      '‮',
      '​',
      '\u{1F600}',
      ':',
      '*',
      '?',
      '"',
      '<',
      '>',
      '|',
      '%2e',
      'CON',
      '.abxbackup',
      '.media',
      '.partial',
      '𝕄',
    ];
    final at = DateTime(2026, 10, 30, 22, 38, 35);
    for (var i = 0; i < _users; i++) {
      final typed = [
        for (var n = random.nextInt(80); n > 0; n--)
          pieces[random.nextInt(pieces.length)],
      ].join();
      final clean = cleanBackupName(typed);
      expect(clean.runes.length, lessThanOrEqualTo(backupNameMaxLength));
      expect(clean, cleanBackupName(clean), reason: 'not stable: $typed');
      final name = backupFileName('murad', at, customName: typed);
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('\\')));
      expect(name, isNot(startsWith('.')));
      expect(name.endsWith('.abxbackup'), isTrue);
      expect(RegExp(r'[\u0000-\u001f‪-‮⁦-⁩]').hasMatch(name), isFalse);
      expect(utf8.encode(name).length, lessThan(255), reason: typed);
      final file = File('${dir.path}/$name')..writeAsStringSync('x');
      expect(file.parent.path, dir.path);
      file.deleteSync();
    }
    expect(dir.listSync(), isEmpty);
  });

  test('$_users accounts: time and name never reach another account', () async {
    SharedPreferences.setMockInitialValues({});
    const store = LocalBackupSettingsStore();
    await Future.wait([
      for (var i = 0; i < _users; i++)
        store.write(
          'user-$i',
          LocalBackupSettings(
            enabled: true,
            backupMinute: i % 1440,
            fileName: 'name $i',
          ),
        ),
    ]);
    final read = await Future.wait([
      for (var i = 0; i < _users; i++) store.read('user-$i'),
    ]);
    for (var i = 0; i < _users; i++) {
      expect(read[i].backupMinute, i % 1440);
      expect(read[i].fileName, 'name $i');
    }
  });

  test(
    '$_diskUsers accounts on one disk, renaming as they go',
    () async {
      final base = Directory.systemTemp.createTempSync('backup_load');
      addTearDown(() => base.deleteSync(recursive: true));
      final watch = Stopwatch()..start();
      Future<void> run(int user) async {
        final dir = AccountBackupDir(base, 'u$user');
        for (var run = 1; run <= 4; run++) {
          final name = backupFileName(
            'u$user',
            DateTime(2026, 10, run, 2),
            customName: ['zz', 'আমার', '', 'aa'][run - 1],
          );
          final partial = await dir.partial(name);
          final writer = await BackupFileWriter.create(
            partial,
            accountKey: backupTestKey,
            userId: 'u$user',
            createdAtMs: run,
          );
          await writer.close();
          await dir.commit(partial, name, {'w$run.abxmedia'});
        }
        final left = await dir.backups();
        expect(left.length, 2, reason: 'u$user');
        final names = left.map((f) => f.uri.pathSegments.last).toList();
        expect(names[0], startsWith('aa-'));
        expect(names[1], startsWith('AbabilX-'));
      }

      for (var start = 0; start < _diskUsers; start += 50) {
        await Future.wait([
          for (var u = start; u < min(start + 50, _diskUsers); u++) run(u),
        ]);
      }
      // ignore: avoid_print
      print('LOAD disk accounts=$_diskUsers ms=${watch.elapsedMilliseconds}');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
