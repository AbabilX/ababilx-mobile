import 'dart:io';

import 'package:ababilx/features/local-backup/auto/account_backup_dir.dart';
import 'package:ababilx/features/local-backup/auto/backup_media_store.dart';
import 'package:ababilx/features/local-backup/restore/backup_importer.dart';
import 'package:ababilx/features/local-backup/restore/backup_restore_source.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_automatic_support.dart';

void main() {
  late Directory base;
  final key = backupTestKey;

  setUp(() => base = Directory.systemTemp.createTempSync('backup_auto'));
  tearDown(() => base.deleteSync(recursive: true));

  File phoneFile(String name, List<int> bytes) =>
      File('${base.path}/$name')..writeAsBytesSync(bytes);

  test(
    'a media file is written once and kept after the phone copy goes',
    () async {
      final dir = AccountBackupDir(base, 'me');
      final clip = phoneFile('clip.mp4', [1, 2, 3]);
      final store = [
        msg('a', ['clip.mp4']),
      ];

      final first = await runAutomatic(dir, store, {
        'https://cdn/clip.mp4': clip,
      }, 1);
      expect(first.written, 1);
      // Cleared from the phone (Manage storage): the backup copy must stay.
      final second = await runAutomatic(dir, store, const {}, 2);
      expect(second.written, 0);
      expect(await dir.mediaFiles(), hasLength(1));
      expect(await dir.backups(), hasLength(2));
    },
  );

  test(
    'keeps two backups, and media only while one of them names it',
    () async {
      final dir = AccountBackupDir(base, 'me');
      final old = phoneFile('old.mp4', [1]);
      final kept = phoneFile('kept.mp4', [2]);
      final files = {'https://cdn/old.mp4': old, 'https://cdn/kept.mp4': kept};

      await runAutomatic(
        dir,
        [
          msg('a', ['old.mp4']),
          msg('bb', ['kept.mp4']),
        ],
        files,
        1,
      );
      // The message with old.mp4 was deleted. One older backup still names it.
      await runAutomatic(
        dir,
        [
          msg('bb', ['kept.mp4']),
        ],
        files,
        2,
      );
      expect(await dir.mediaFiles(), hasLength(2));
      await runAutomatic(
        dir,
        [
          msg('bb', ['kept.mp4']),
        ],
        files,
        3,
      );
      final left = await dir.mediaFiles();
      expect(left, hasLength(1));
      expect(
        left.single.path,
        endsWith(BackupMediaStore.nameFor('https://cdn/kept.mp4')),
      );
      expect(await dir.backups(), hasLength(2));
      expect(dir.root.listSync().whereType<File>(), hasLength(4));
    },
  );

  test(
    'a file that would eat the reserve is left out and tried again',
    () async {
      final dir = AccountBackupDir(base, 'me');
      final clip = phoneFile('clip.mp4', List.filled(100, 7));
      final files = {'https://cdn/clip.mp4': clip};
      final store = [
        msg('a', ['clip.mp4']),
      ];

      final tight = await runAutomatic(
        dir,
        store,
        files,
        1,
        free: 150,
        reserve: 100,
      );
      expect(tight.skippedForSpace, 1);
      expect(await dir.mediaFiles(), isEmpty);
      final roomy = await runAutomatic(
        dir,
        store,
        files,
        2,
        free: 1000,
        reserve: 100,
      );
      expect(roomy.written, 1);
    },
  );

  test(
    'restore source: newest first, this account only, media readable',
    () async {
      final dir = AccountBackupDir(base, 'me');
      final clip = phoneFile('clip.mp4', [9, 8, 7]);
      final store = [
        msg('a', ['clip.mp4']),
      ];
      await runAutomatic(dir, store, {'https://cdn/clip.mp4': clip}, 1);
      await runAutomatic(dir, store, const {}, 2);
      expect(await accountDirSources(AccountBackupDir(base, 'other')), isEmpty);

      final sources = await accountDirSources(dir);
      expect(sources, hasLength(2));
      expect(sources.first.main.path, endsWith('me-2.abxbackup'));
      expect(sources.first.media, hasLength(1));

      final adopted = <String, List<int>>{};
      final saved = <ChatMessage>[];
      BackupImporter importer() => BackupImporter(
        saveMessages: (m) async => saved.addAll(m),
        saveBodies: (_) async {},
        adoptFile:
            ({
              required fileUrl,
              required fileName,
              required contentType,
              required source,
            }) async => adopted[fileUrl] = source.readAsBytesSync(),
        tempDir: Directory('${base.path}/tmp'),
      );
      await importer().run(File(sources.first.main.path!), key);
      final media = await importer().run(
        File(sources.first.media.single.path!),
        key,
      );
      expect(saved.map((m) => m.id), ['a']);
      expect(media.files, 1);
      expect(adopted, {
        'https://cdn/clip.mp4': [9, 8, 7],
      });
    },
  );
}
