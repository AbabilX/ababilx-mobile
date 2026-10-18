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

/// The write pass shares one stream of store pages across the weeks it
/// seals, and reports how far it is. Page sizes here are odd on purpose, so
/// weeks start and end mid-page.
ChatMessage _at(String id, DateTime at) => ChatMessage(
  id: id,
  conversationId: 'dm',
  userId: 'peer',
  body: 'text $id',
  createdAt: at.toUtc().toIso8601String(),
);

/// 3 messages a day for 30 days: five weeks, every boundary inside a page.
List<ChatMessage> _month() => [
  for (var d = 0; d < 30; d++)
    for (var h = 0; h < 3; h++)
      _at('d$d-$h', DateTime.utc(2026, 9, 1 + d, 8 + h)),
];

class _Store {
  _Store(List<ChatMessage> rows, this.pageSize)
    : rows = [...rows]
        ..sort((a, b) {
          final t = messageTimeMs(a).compareTo(messageTimeMs(b));
          return t != 0
              ? t
              : localMessageRowId(a).compareTo(localMessageRowId(b));
        });

  final List<ChatMessage> rows;
  final int pageSize;
  int reads = 0;

  Future<List<ChatMessage>> page(int? afterMs, String? afterId) async {
    reads++;
    return rows
        .where((m) {
          if (afterMs == null) return true;
          final t = messageTimeMs(m);
          return t > afterMs ||
              (t == afterMs && localMessageRowId(m).compareTo(afterId!) > 0);
        })
        .take(pageSize)
        .toList();
  }
}

void main() {
  late Directory base;
  setUp(() => base = Directory.systemTemp.createTempSync('backup_progress'));
  tearDown(() => base.deleteSync(recursive: true));

  Future<(BackupExportStats, List<(int, int)>)> backUp(
    AccountBackupDir dir,
    _Store store,
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
    final progress = <(int, int)>[];
    final stats = await BackupExporter(
      readPage: store.page,
      allows: (_) => true,
      openBody: (_) async => null,
      localFile: (_) async => null,
      choices: const BackupChoices(),
      conversations: {'dm': backupTestDm},
      media: media,
      segments: segments,
    ).run(writer, onProgress: (done, total) => progress.add((done, total)));
    await writer.close();
    await dir.commit(partial, name, {...media.wanted, ...segments.wanted});
    return (stats, progress);
  }

  Future<List<String>> restoredIds(AccountBackupDir dir) async {
    final source = (await accountDirSources(dir)).first;
    final ids = <String>[];
    final weeks = <String>[];
    BackupImporter importer() => BackupImporter(
      saveMessages: (m) async => ids.addAll(m.map((e) => e.id)),
      saveBodies: (_) async {},
      adoptFile:
          ({
            required fileUrl,
            required fileName,
            required contentType,
            required source,
          }) async {},
      tempDir: Directory('${base.path}/tmp'),
      onOtherFrame: (frame) async {
        if (frame['t'] == 'seg') weeks.add(frame['n'] as String);
      },
    );
    await importer().run(File(source.main.path!), backupTestKey);
    for (final file in restoreReadOrder(source.media, weeks)) {
      await importer().run(File(file.path!), backupTestKey);
    }
    return ids;
  }

  for (final size in [1, 2, 7, 500]) {
    test('pages of $size: every week whole, read once each way', () async {
      final dir = AccountBackupDir(base, 'me');
      final rows = _month();
      final store = _Store(rows, size);
      final (stats, progress) = await backUp(dir, store, 1);
      expect(stats.messages, rows.length);
      expect(stats.sealed, rows.length);
      // Scan and write each read the store through once (plus the empty
      // page that ends a pass), never a page per week again.
      final pages = (rows.length / size).ceil();
      expect(store.reads, lessThanOrEqualTo(2 * (pages + 1)));
      final ids = await restoredIds(dir);
      expect(ids, hasLength(rows.length), reason: 'no row twice, none lost');
      expect(ids.toSet(), rows.map((m) => m.id).toSet());

      // The sealing part counts up to its own total and ends on it.
      final sealing = progress.where((p) => p.$2 > 0).toList();
      expect(sealing.first, (0, rows.length));
      expect(sealing.last, (rows.length, rows.length));
      for (var i = 1; i < sealing.length; i++) {
        expect(sealing[i].$1, greaterThanOrEqualTo(sealing[i - 1].$1));
      }
    });
  }

  test('only the changed weeks count towards the total', () async {
    final dir = AccountBackupDir(base, 'me');
    await backUp(dir, _Store(_month(), 7), 1);
    final next = [..._month(), _at('new', DateTime.utc(2026, 9, 30, 20))];
    final (stats, progress) = await backUp(dir, _Store(next, 7), 2);
    final week = BackupMessageSegments.weekOf(messageTimeMs(next.last));
    final inWeek = next
        .where((m) => BackupMessageSegments.weekOf(messageTimeMs(m)) == week)
        .length;
    expect(stats.sealed, inWeek);
    expect(progress.where((p) => p.$2 > 0).last, (inWeek, inWeek));
    expect(await restoredIds(dir), hasLength(next.length));
  });

  test('nothing changed: the total is zero and nothing is sealed', () async {
    final dir = AccountBackupDir(base, 'me');
    await backUp(dir, _Store(_month(), 7), 1);
    final (stats, progress) = await backUp(dir, _Store(_month(), 7), 2);
    expect(stats.sealed, 0);
    expect(progress.last, (0, 0));
  });
}
