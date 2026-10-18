import 'dart:io';

import 'package:ababilx/features/local-backup/auto/account_backup_dir.dart';
import 'package:ababilx/features/local-backup/auto/backup_folder_view.dart';
import 'package:ababilx/features/local-backup/auto/backup_media_store.dart';
import 'package:ababilx/features/local-backup/auto/backup_message_segments.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_automatic_support.dart';

/// After a reinstall, Android shows the new install a file the old one wrote
/// when asked by name, but hides it from listings and refuses to read it.
/// Such a file must never count as backed up (device, 2026-10-18: 359
/// photos "held", 0 restored).
void main() {
  late Directory base;
  setUp(() => base = Directory.systemTemp.createTempSync('folder_view'));
  tearDown(() => base.deleteSync(recursive: true));

  final photo = BackupMediaStore.nameFor('https://cdn/a.jpg');
  final week = 'm${'3' * 39}${AccountBackupDir.mediaExtension}';

  /// A folder whose [strangers] exist by name but are not this install's.
  BackupFolderView view(
    Directory dir, {
    Map<String, int> own = const {},
    Set<String> strangers = const {},
    String tag = 'install-b',
  }) => BackupFolderView(
    dir,
    {...own},
    installTag: tag,
    exists: (path) async =>
        strangers.contains(path.split('/').last) || File(path).existsSync(),
  );

  test(
    'a stranger\'s file is not held, and its name goes to an alternative',
    () async {
      final v = view(base, strangers: {photo});
      expect(v.held(photo), isNull);
      final free = await v.free(photo);
      expect(free, isNot(photo));
      expect(free, v.candidates(photo).last);
    },
  );

  test('this install\'s own file is held; an empty one is rewritten', () async {
    expect(view(base, own: {photo: 10}).held(photo), photo);
    final empty = view(base, own: {photo: 0});
    expect(empty.held(photo), isNull);
    expect(await empty.free(photo), photo);
  });

  test('alternatives keep the shape and differ per install', () {
    final a = view(base, tag: 'a').candidates(photo).last;
    final b = view(base, tag: 'b').candidates(photo).last;
    expect(a, isNot(b));
    expect(a.length, photo.length);
    expect(BackupMessageSegments.isSegmentName(a), isFalse);
    final weekAlt = view(base).candidates(week).last;
    expect(weekAlt.length, week.length);
    expect(BackupMessageSegments.isSegmentName(weekAlt), isTrue);
  });

  test('both names taken by strangers: nothing to write under', () async {
    final v = view(base, strangers: {photo});
    final alt = v.candidates(photo).last;
    expect(await view(base, strangers: {photo, alt}).free(photo), isNull);
  });

  test('a reinstalled phone stores its own copy and finds it next run', () async {
    final dir = AccountBackupDir(base, 'me');
    await dir.media.create(recursive: true);
    final local = File('${base.path}/kept.mp4')..writeAsBytesSync([1, 2, 3]);
    final url = 'https://cdn/kept.mp4';
    final stranger = BackupMediaStore.nameFor(url);
    final store = BackupMediaStore(
      dir: dir.media,
      accountKey: backupTestKey,
      userId: 'me',
      freeBytes: 1 << 40,
      reserveBytes: 0,
      folderView: view(dir.media, strangers: {stranger}),
    );
    expect(await store.holds(url), isFalse, reason: 'not ours to count');
    expect(await store.put({'u': url, 'n': 'kept.mp4'}, local), isTrue);
    expect(store.written, 1);
    final name = store.wanted.single;
    expect(name, isNot(stranger));
    expect(File('${dir.media.path}/$name').lengthSync(), greaterThan(0));
    // The next run of this install finds it under the alternative.
    final next = BackupMediaStore(
      dir: dir.media,
      accountKey: backupTestKey,
      userId: 'me',
      freeBytes: 1 << 40,
      reserveBytes: 0,
      installTag: 'install-b',
    );
    expect(await next.holds(url), isTrue);
    expect(next.wanted.single, name);
  });

  test('a week a stranger sealed is sealed again under ours', () async {
    final dir = AccountBackupDir(base, 'me');
    final segments = BackupMessageSegments(
      dir: dir.media,
      accountKey: backupTestKey,
      userId: 'me',
      folderView: view(dir.media, strangers: {week}),
    );
    expect(await segments.keep(week), isNull);
    final (out, partial) = await segments.open();
    await out.addFrame({'t': 'msg', 'm': <String, dynamic>{}});
    await out.close();
    final name = await segments.commit(partial, week);
    expect(name, isNot(week));
    expect(BackupMessageSegments.isSegmentName(name), isTrue);
    expect(segments.wanted, {name});
    expect(File('${dir.media.path}/$name').existsSync(), isTrue);
  });
}
