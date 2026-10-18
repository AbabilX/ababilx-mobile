import 'dart:io';

import 'package:ababilx/features/local-backup/auto/account_backup_dir.dart';
import 'package:ababilx/features/local-backup/auto/backup_media_store.dart';
import 'package:ababilx/features/local-backup/auto/backup_message_segments.dart';
import 'package:ababilx/features/local-backup/data/backup_choices.dart';
import 'package:ababilx/features/local-backup/export/backup_exporter.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:ababilx/features/local-backup/restore/backup_importer.dart';
import 'package:ababilx/features/local-backup/restore/backup_restore_source.dart';
import 'package:ababilx/features/messages/data/local/chat_message_row.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_automatic_support.dart';

ChatMessage _at(String id, DateTime at, {String body = ''}) => ChatMessage(
  id: id,
  conversationId: 'dm',
  userId: 'peer',
  body: body.isEmpty ? 'text $id' : body,
  createdAt: at.toUtc().toIso8601String(),
);

/// The store's export order and cursor, two rows a page so every pass pages.
Future<List<ChatMessage>> Function(int?, String?) _pages(
  List<ChatMessage> store,
) {
  final sorted = [...store]
    ..sort((a, b) {
      final t = messageTimeMs(a).compareTo(messageTimeMs(b));
      return t != 0 ? t : localMessageRowId(a).compareTo(localMessageRowId(b));
    });
  return (afterMs, afterId) async {
    final after = sorted.where((m) {
      if (afterMs == null) return true;
      final t = messageTimeMs(m);
      return t > afterMs ||
          (t == afterMs && localMessageRowId(m).compareTo(afterId ?? '') > 0);
    });
    return after.take(2).toList();
  };
}

class _Run {
  _Run(this.stats, this.segments, this.main);
  final BackupExportStats stats;
  final BackupMessageSegments segments;
  final File main;
}

Future<_Run> _backUp(
  AccountBackupDir dir,
  List<ChatMessage> store,
  int stamp,
) async {
  final name = 'me-$stamp.abxbackup';
  final media = BackupMediaStore(
    dir: dir.media,
    accountKey: backupTestKey,
    userId: 'me',
    freeBytes: 1 << 40,
    reserveBytes: 0,
  );
  final segments = BackupMessageSegments(
    dir: dir.media,
    accountKey: backupTestKey,
    userId: 'me',
  );
  final partial = await dir.partial(name);
  final writer = await BackupFileWriter.create(
    partial,
    accountKey: backupTestKey,
    userId: 'me',
    createdAtMs: stamp,
  );
  final stats = await BackupExporter(
    readPage: _pages(store),
    allows: (_) => true,
    openBody: (_) async => null,
    localFile: (_) async => null,
    choices: const BackupChoices(),
    conversations: {'dm': backupTestDm},
    media: media,
    segments: segments,
  ).run(writer);
  await writer.close();
  final main = await dir.commit(partial, name, {
    ...media.wanted,
    ...segments.wanted,
  });
  return _Run(stats, segments, main);
}

/// Restores the newest backup the way the runner does: main file, then the
/// listed weeks and the other media.
Future<List<ChatMessage>> _restore(AccountBackupDir dir) async {
  final sources = await accountDirSources(dir);
  final source = sources.first;
  final restored = <ChatMessage>[];
  final weeks = <String>[];
  BackupImporter importer() => BackupImporter(
    saveMessages: (m) async => restored.addAll(m),
    saveBodies: (_) async {},
    adoptFile:
        ({
          required fileUrl,
          required fileName,
          required contentType,
          required source,
        }) async {},
    tempDir: Directory('${dir.root.path}/../tmp-${restored.length}'),
    onOtherFrame: (frame) async {
      if (frame['t'] == 'seg') weeks.add(frame['n'] as String);
    },
  );
  await importer().run(File(source.main.path!), backupTestKey);
  for (final file in restoreReadOrder(source.media, weeks)) {
    await importer().run(File(file.path!), backupTestKey);
  }
  return restored;
}

void main() {
  late Directory base;
  setUp(() => base = Directory.systemTemp.createTempSync('backup_weeks'));
  tearDown(() => base.deleteSync(recursive: true));

  final sep1 = DateTime.utc(2026, 9, 1, 10);
  final sep20 = DateTime.utc(2026, 9, 20, 10);
  final oct8 = DateTime.utc(2026, 10, 8, 10);

  List<ChatMessage> history() => [
    _at('a1', sep1),
    _at('a2', sep1.add(const Duration(minutes: 1))),
    _at('a3', sep1.add(const Duration(minutes: 2))),
    _at('b1', sep20),
    _at('c1', oct8),
    _at('c2', oct8.add(const Duration(hours: 1))),
  ];

  test('the first run seals every week, the next one none', () async {
    final dir = AccountBackupDir(base, 'me');
    final first = await _backUp(dir, history(), 1);
    expect(first.stats.messages, 6);
    expect(first.stats.sealed, 6);
    expect(first.segments.written, 3);

    final second = await _backUp(dir, history(), 2);
    expect(second.stats.messages, 6);
    expect(second.stats.sealed, 0, reason: 'nothing changed, nothing sealed');
    expect(second.segments.written, 0);
    expect(second.segments.reused, 3);
  });

  test('a new message reseals only its own week', () async {
    final dir = AccountBackupDir(base, 'me');
    await _backUp(dir, history(), 1);
    final next = await _backUp(dir, [
      ...history(),
      _at('c3', oct8.add(const Duration(hours: 2))),
    ], 2);
    expect(next.segments.written, 1);
    expect(next.segments.reused, 2);
    expect(next.stats.sealed, 3, reason: "this week's three messages");
  });

  test(
    'an edit, or an old page fetched later, reseals that old week',
    () async {
      final dir = AccountBackupDir(base, 'me');
      await _backUp(dir, history(), 1);
      final edited = history()
        ..[0] = _at('a1', sep1, body: 'edited a1')
        // Scrollback brought an older message the phone never had.
        ..add(_at('a0', sep1.subtract(const Duration(minutes: 1))));
      final next = await _backUp(dir, edited, 2);
      expect(next.segments.written, 1);
      expect(next.stats.sealed, 4);
    },
  );

  test('a restore reads the listed weeks and brings everything back', () async {
    final dir = AccountBackupDir(base, 'me');
    await _backUp(dir, history(), 1);
    await _backUp(dir, [
      ...history(),
      _at('c3', oct8.add(const Duration(hours: 2))),
    ], 2);
    final restored = await _restore(dir);
    final ids = restored.map((m) => m.id).toSet();
    expect(ids, {'a1', 'a2', 'a3', 'b1', 'c1', 'c2', 'c3'});
    // The other kept backup's copy of this week is not read again.
    expect(restored.length, 7);
  });

  test('pruning drops weeks no kept backup lists', () async {
    final dir = AccountBackupDir(base, 'me');
    await _backUp(dir, history(), 1);
    for (var i = 0; i < 3; i++) {
      await _backUp(dir, [
        ...history(),
        _at('c$i-new', oct8.add(Duration(hours: 3 + i))),
      ], 2 + i);
    }
    final weeks = (await dir.mediaFiles())
        .map((f) => f.uri.pathSegments.last)
        .where(BackupMessageSegments.isSegmentName)
        .toList();
    // Two old weeks shared by both kept backups, plus this week twice.
    expect(weeks, hasLength(4));
  });

  test('read order: listed weeks first, unlisted weeks out, media kept', () {
    final week = 'm${'1' * 39}.abxmedia';
    final stale = 'm${'2' * 39}.abxmedia';
    final photo = '${'a' * 40}.abxmedia';
    final media = [
      BackupSourceFile.local('/x/$photo', 1),
      BackupSourceFile.local('/x/$stale', 1),
      BackupSourceFile.local('/x/$week', 1),
    ];
    final order = restoreReadOrder(media, [week]);
    expect(order.map((f) => f.name), [week, photo]);
    // A backup from before weeks lists none, and reads its media alone.
    expect(restoreReadOrder(media, const []).map((f) => f.name), [photo]);
  });
}
