import 'dart:convert';

import '../../messages/data/local/chat_message_row.dart';
import '../../messages/data/models/chat_message.dart';
import '../auto/backup_message_segments.dart';
import '../format/backup_errors.dart';
import '../format/backup_file_writer.dart';
import 'backup_export_pager.dart';
import 'backup_exporter.dart';
import 'backup_yield.dart';

/// The automatic backup's messages, in two passes over the store.
///
/// **Scan**: every included row is hashed into its week — cheap, no message
/// is opened — and the files go to the media store as before. **Write**: only
/// a week whose hash names no file in the folder is read again, opened and
/// sealed. A week an earlier run already sealed costs one hash.
///
/// The write pass hashes what it actually wrote and names the file by that,
/// so a message landing between the passes can only make a week be written
/// again next run — never a file whose name describes other content.
///
/// Progress: `(scanned, 0)` while scanning (no total yet), then
/// `(sealed, toSeal)` — the messages of the weeks that changed, the only
/// part that takes time.
class BackupSegmentExport {
  BackupSegmentExport(this._export, this._segments);

  final BackupExporter _export;
  final BackupMessageSegments _segments;

  /// Messages opened side by side: the key and restored-text lookups are
  /// channel round trips, and waiting on one at a time was most of the run.
  static const _batch = 32;

  Future<BackupExportStats> run(
    BackupFileWriter writer, {
    BackupProgress? onProgress,
    bool Function()? shouldContinue,
  }) async {
    void check() {
      if (shouldContinue?.call() == false) throw const BackupCancelledError();
    }

    final clock = Stopwatch()..start();
    final turn = BackupYield();
    final pager = BackupExportPager(_export.readPage);
    final weeks = <BackupWeekScan>[];
    final seen = <String>{};
    var messages = 0;
    var files = 0;
    int? afterMs;
    String? afterId;
    BackupWeekScan? current;
    while (true) {
      check();
      await turn.maybe();
      final message = await pager.peek();
      if (message == null) break;
      pager.take();
      if (_export.includes(message)) {
        final week = BackupMessageSegments.weekOf(messageTimeMs(message));
        if (current == null || current.week != week) {
          // The cursor still names the row before this one.
          current = BackupWeekScan(week, afterMs: afterMs, afterId: afterId);
          weeks.add(current);
        }
        current.add(jsonEncode(_export.storedRow(message)));
        messages++;
        files += await _export.addFiles(message, seen, writer);
        if (messages % 250 == 0) onProgress?.call(messages, 0);
      }
      afterMs = messageTimeMs(message);
      afterId = localMessageRowId(message);
    }
    final scanMs = clock.elapsedMilliseconds;
    final scanRead = pager.watch.elapsedMilliseconds;

    final names = <BackupWeekScan, String>{};
    final dirty = <BackupWeekScan>{};
    for (final week in weeks) {
      final name = _segments.nameFor(week.week, week.hash.close());
      final kept = await _segments.keep(name);
      names[week] = kept ?? name;
      if (kept == null) dirty.add(week);
    }
    final toSeal = dirty.fold<int>(0, (sum, w) => sum + w.count);
    onProgress?.call(0, toSeal);

    final opening = Stopwatch();
    var sealed = 0;
    var unreadable = 0;
    final listed = <Map<String, dynamic>>[];
    for (final week in weeks) {
      check();
      var name = names[week]!;
      var count = week.count;
      if (dirty.contains(week)) {
        final out = await _write(
          week,
          pager,
          opening,
          turn,
          check: check,
          onSealed: (n) => onProgress?.call(sealed + n, toSeal),
        );
        name = out.name;
        count = out.count;
        sealed += out.count;
        unreadable += out.unreadable;
      }
      listed.add({'t': 'seg', 'n': name, 'w': week.week, 'c': count});
    }
    // Newest week first: a restore brings back this week's chats before
    // last year's.
    for (final frame in listed.reversed) {
      await writer.addFrame(frame);
    }
    return BackupExportStats(
      messages: messages,
      files: files,
      unreadable: unreadable,
      sealed: sealed,
      timing:
          'scan=${scanMs}ms(read=${scanRead}ms) '
          'write=${clock.elapsedMilliseconds - scanMs}ms'
          '(read=${pager.watch.elapsedMilliseconds - scanRead}ms '
          'open=${opening.elapsedMilliseconds}ms) pages=${pager.pages}',
    );
  }

  Future<({String name, int count, int unreadable})> _write(
    BackupWeekScan week,
    BackupExportPager pager,
    Stopwatch opening,
    BackupYield turn, {
    required void Function() check,
    required void Function(int sealed) onSealed,
  }) async {
    final (out, partial) = await _segments.open();
    try {
      final hash = BackupWeekHasher();
      var count = 0;
      var unreadable = 0;
      final batch = <ChatMessage>[];
      Future<void> flush() async {
        if (batch.isEmpty) return;
        opening.start();
        final texts = await Future.wait(
          batch.map(
            (m) => m.isEncrypted ? _export.openBody(m) : Future.value(null),
          ),
        );
        opening.stop();
        for (var i = 0; i < batch.length; i++) {
          await turn.maybe();
          final stored = jsonEncode(_export.storedRow(batch[i]));
          hash.add(stored);
          final text = texts[i];
          if (batch[i].isEncrypted && text == null) unreadable++;
          await out.addFrameJson(
            '{"t":"msg","m":$stored'
            '${text == null ? '' : ',"p":${jsonEncode(text)}'}}',
          );
        }
        count += batch.length;
        batch.clear();
        onSealed(count);
      }

      pager.seek(week.afterMs, week.afterId);
      while (true) {
        check();
        await turn.maybe();
        final message = await pager.peek();
        if (message == null) break;
        final at = BackupMessageSegments.weekOf(messageTimeMs(message));
        if (at > week.week) break;
        pager.take();
        if (at < week.week || !_export.includes(message)) continue;
        batch.add(message);
        if (batch.length >= _batch) await flush();
      }
      await flush();
      await out.close();
      final name = await _segments.commit(
        partial,
        _segments.nameFor(week.week, hash.close()),
      );
      return (name: name, count: count, unreadable: unreadable);
    } catch (_) {
      await out.abort();
      rethrow;
    }
  }
}
