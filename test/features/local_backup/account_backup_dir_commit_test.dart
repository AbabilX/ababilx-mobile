import 'dart:io';

import 'package:ababilx/features/local-backup/auto/account_backup_dir.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_automatic_support.dart';

/// What a commit leaves in the account folder when a run, or the phone, was
/// cut off at a bad moment.
void main() {
  late Directory base;
  setUp(() => base = Directory.systemTemp.createTempSync('backup_commit'));
  tearDown(() => base.deleteSync(recursive: true));

  Future<File> sealed(AccountBackupDir dir, String name, int stamp) async {
    final partial = await dir.partial(name);
    final writer = await BackupFileWriter.create(
      partial,
      accountKey: backupTestKey,
      userId: 'me',
      createdAtMs: stamp,
    );
    await writer.close();
    return partial;
  }

  test('every backup keeps its media list; a stray list is cleared', () async {
    final dir = AccountBackupDir(base, 'me');
    await dir.root.create(recursive: true);
    // A run cut off after writing its list, before naming its backup.
    final stray = File('${dir.root.path}/me-0.abxbackup.media')
      ..writeAsStringSync('gone.abxmedia');
    await dir.media.create(recursive: true);
    final kept = File('${dir.media.path}/kept.abxmedia')
      ..writeAsStringSync('k');
    final old = File('${dir.media.path}/old.abxmedia')..writeAsStringSync('o');

    final done = await dir.commit(
      await sealed(dir, 'me-1.abxbackup', 1),
      'me-1.abxbackup',
      {'kept.abxmedia'},
    );
    expect(File('${done.path}.media').readAsStringSync(), 'kept.abxmedia');
    expect(stray.existsSync(), isFalse);
    expect(kept.existsSync(), isTrue);
    expect(old.existsSync(), isFalse);
  });

  test('the newest two stay, with every file either one names', () async {
    final dir = AccountBackupDir(base, 'me');
    for (var i = 1; i <= 4; i++) {
      await dir.commit(
        await sealed(dir, 'me-$i.abxbackup', i),
        'me-$i.abxbackup',
        {'w$i.abxmedia'},
      );
      await dir.media.create(recursive: true);
      File('${dir.media.path}/w$i.abxmedia').writeAsStringSync('$i');
    }
    // One more run, so the prune sees the files the runs above wrote.
    await dir.commit(await sealed(dir, 'me-5.abxbackup', 5), 'me-5.abxbackup', {
      'w5.abxmedia',
      'w4.abxmedia',
    });
    final names = (await dir.backups()).map((f) => f.uri.pathSegments.last);
    expect(names, ['me-5.abxbackup', 'me-4.abxbackup']);
    final media = (await dir.mediaFiles())
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(media, {'w4.abxmedia'});
    final lists = dir.root
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.endsWith('.media'))
        .toSet();
    expect(lists, {'me-5.abxbackup.media', 'me-4.abxbackup.media'});
  });
}
