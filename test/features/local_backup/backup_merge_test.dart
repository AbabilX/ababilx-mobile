import 'dart:convert';
import 'dart:io';

import 'package:ababilx/features/local-backup/extras/backup_pref_merge.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:ababilx/features/local-backup/restore/backup_importer.dart';
import 'package:ababilx/features/messages/data/local/archive_page_merge.dart';
import 'package:ababilx/features/messages/data/local/chat_message_row.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage m(String id, int minute, {String body = '', String? ref}) =>
    ChatMessage(
      id: id,
      conversationId: 'c',
      userId: 'u',
      body: body.isEmpty ? 'b $id' : body,
      clientRef: ref,
      createdAt: DateTime.utc(2026, 10, 19, 10, minute).toIso8601String(),
    );

ArchiveRowKey keyOf(ChatMessage x) =>
    (ms: messageTimeMs(x), id: localMessageRowId(x));

/// The two Android stores, read the way `exportPage` reads them.
class TwoStores {
  TwoStores(this.native, this.drift);
  final List<ChatMessage> native;
  final List<ChatMessage> drift;

  List<T> _after<T>(
    List<ChatMessage> rows,
    int? ms,
    String? id,
    int limit,
    T Function(ChatMessage) map,
  ) {
    final sorted = [...rows]
      ..sort((a, b) => compareArchiveKeys(keyOf(a), keyOf(b)));
    return [
      for (final r in sorted)
        if (ms == null ||
            compareArchiveKeys(keyOf(r), (ms: ms, id: id ?? '')) > 0)
          map(r),
    ].take(limit).toList();
  }

  Future<List<ChatMessage>> page(int? ms, String? id, int limit) =>
      mergeArchivePage(
        primary: _after(native, ms, id, limit, (r) => r),
        mirrorKeys: _after(drift, ms, id, limit, keyOf),
        mirrorRows: (ids) async => [
          for (final r in drift)
            if (ids.contains(localMessageRowId(r))) r,
        ],
        limit: limit,
      );

  /// Every row the cursor walks, page by page, as the backup pager does.
  Future<List<ChatMessage>> walk(int limit) async {
    final out = <ChatMessage>[];
    int? ms;
    String? id;
    while (true) {
      final rows = await page(ms, id, limit);
      if (rows.isEmpty) return out;
      out.addAll(rows);
      ms = messageTimeMs(rows.last);
      id = localMessageRowId(rows.last);
    }
  }
}

void main() {
  group('mergeArchivePage', () {
    test('rows only the rollback copy holds are backed up too', () async {
      // a, c live in both; b and d were never migrated to SQLCipher.
      final stores = TwoStores(
        [m('a', 1), m('c', 3)],
        [m('a', 1), m('b', 2), m('c', 3), m('d', 4)],
      );
      expect((await stores.walk(500)).map((x) => x.id), ['a', 'b', 'c', 'd']);
    });

    test(
      'a row in both stores comes once, and the SQLCipher copy wins',
      () async {
        final stores = TwoStores(
          [m('a', 1, body: 'edited')],
          [m('a', 1, body: 'stale')],
        );
        final all = await stores.walk(500);
        expect(all, hasLength(1));
        expect(all.single.body, 'edited');
      },
    );

    test('small pages: every row once, none skipped at a page edge', () async {
      final native = [for (var i = 0; i < 20; i += 2) m('n$i', i)];
      final drift = [
        ...native,
        for (var i = 1; i < 20; i += 2) m('d$i', i),
        m('same', 5), // same minute as d5: ordered by row id
      ];
      final stores = TwoStores(native, drift);
      for (final limit in [1, 2, 3, 7]) {
        final ids = (await stores.walk(limit)).map((x) => x.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'limit $limit');
        expect(ids, hasLength(21), reason: 'limit $limit');
      }
    });

    test('a pending send under its client ref is one row, not two', () async {
      final sent = m('server-id', 1, ref: 'ref-1');
      final stores = TwoStores([sent], [sent]);
      expect(await stores.walk(500), hasLength(1));
    });
  });

  group('BackupPrefMerge', () {
    test('favourites: phone first, backup fills in, no repeats, cap 12', () {
      final phone = jsonEncode([
        {'c': 'x', 'n': 'X now'},
      ]);
      final backup = jsonEncode([
        {'c': 'x', 'n': 'X old'},
        for (var i = 0; i < 15; i++) {'c': 'b$i'},
      ]);
      final out =
          jsonDecode(
                BackupPrefMerge.merge('call_favorites_v1:me', phone, backup)
                    as String,
              )
              as List;
      expect(out, hasLength(12));
      expect(out.first, {'c': 'x', 'n': 'X now'});
      expect(out.where((e) => e['c'] == 'x'), hasLength(1));
    });

    test('nothing new: the phone value is left alone', () {
      final same = jsonEncode([
        {'c': 'x'},
      ]);
      expect(BackupPrefMerge.merge('call_favorites_v1:me', same, same), isNull);
      expect(
        BackupPrefMerge.merge('ababilx_wallpaper_photos_v1', ['/a'], ['/a']),
        isNull,
      );
    });

    test('wallpaper photos union', () {
      expect(
        BackupPrefMerge.merge(
          'ababilx_wallpaper_photos_v1',
          ['/a'],
          ['/b', '/a'],
        ),
        ['/a', '/b'],
      );
    });

    test('single values never merge', () {
      expect(BackupPrefMerge.merges('ababilx_theme_mode'), isFalse);
      expect(BackupPrefMerge.merges('call_favorites_v1:me'), isTrue);
    });
  });

  test('a restore passes over files the phone already holds', () async {
    final dir = Directory.systemTemp.createTempSync('backup_merge');
    addTearDown(() => dir.deleteSync(recursive: true));
    final key = List<int>.generate(32, (i) => i);
    final file = File('${dir.path}/b.abxbackup');
    final writer = await BackupFileWriter.create(
      file,
      accountKey: key,
      userId: 'me',
      createdAtMs: 1,
    );
    for (final name in ['have', 'new']) {
      final src = File('${dir.path}/$name')..writeAsBytesSync([1, 2]);
      await writer.addFile({'u': 'https://cdn/$name', 'n': name}, src);
    }
    await writer.close();

    final adopted = <String>[];
    Future<List<String>> run() async {
      adopted.clear();
      await BackupImporter(
        saveMessages: (_) async {},
        saveBodies: (_) async {},
        adoptFile:
            ({
              required fileUrl,
              required fileName,
              required contentType,
              required source,
            }) async => adopted.add(fileUrl),
        holdsFile: (url) async => url.endsWith('/have'),
        tempDir: Directory('${dir.path}/t'),
      ).run(file, key);
      return adopted;
    }

    expect(await run(), ['https://cdn/new']);
  });
}
