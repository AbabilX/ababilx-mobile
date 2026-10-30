import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'backup_crypto.dart';
import 'backup_errors.dart';
import 'backup_header.dart';
import 'backup_record_worker.dart';

/// Where one restored file's bytes go. Closed exactly once, after its last
/// part, before the next record is handled.
abstract interface class BackupFileSink {
  Future<void> add(List<int> bytes);
  Future<void> close();
}

/// Reads a backup back: `record -> AES-GCM open -> type -> frames or bytes`.
///
/// Streams record by record, so a restore of a few gigabytes holds one record
/// in memory. Authenticity is per record and positional (see
/// [BackupCrypto.recordAad]); completeness is the END record. A file that
/// stops before END is refused with [BackupIncompleteError] — whatever was
/// already applied stays, because every row is written by id and a second
/// restore converges, but the caller is told it was cut short.
class BackupFileReader {
  BackupFileReader(this.file, this.accountKey);

  final File file;
  final List<int> accountKey;

  /// The clear header alone: whose file this is and when it was written.
  static Future<BackupHeader> readHeader(File file) async {
    final input = await file.open();
    try {
      return (await _header(input)).$1;
    } finally {
      await input.close();
    }
  }

  Future<void> run({
    required Future<void> Function(Map<String, dynamic> frame) onFrame,
    required Future<BackupFileSink?> Function(Map<String, dynamic> file) onFile,
    bool Function()? shouldContinue,
    void Function(int read, int total)? onBytes,
  }) async {
    final input = await file.open();
    final total = await input.length();
    BackupFileSink? current;
    Future<void> closeCurrent() async {
      final sink = current;
      current = null;
      if (sink != null) await sink.close();
    }

    try {
      final (header, encoded) = await _header(input);
      final expected = await BackupCrypto.keyCheck(accountKey, header.salt);
      if (!_same(expected, header.keyCheck)) {
        throw const BackupWrongAccountError();
      }
      final key = await (await BackupCrypto.fileKey(
        accountKey,
        header.salt,
      )).extractBytes();
      var index = 0;
      var frames = 0;
      var files = 0;
      while (true) {
        if (shouldContinue?.call() == false) throw const BackupCancelledError();
        final (type, body) = await _nextRecord(
          input,
          key,
          encoded.digest,
          index++,
        );
        onBytes?.call(await input.position(), total);
        if (type == BackupRecordType.filePart) {
          await current?.add(body);
          continue;
        }
        await closeCurrent();
        if (type == BackupRecordType.end) {
          final end = jsonDecode(utf8.decode(body)) as Map;
          if (end['frames'] != frames || end['files'] != files) {
            throw const BackupIncompleteError();
          }
          return;
        }
        if (type != BackupRecordType.frames) continue; // a newer record kind
        final text = utf8.decode(body); // gunzipped by the worker
        for (final line in const LineSplitter().convert(text)) {
          if (line.isEmpty) continue;
          frames++;
          final frame = _frame(line);
          if (frame == null) continue;
          if (frame['t'] == 'file') {
            files++;
            await closeCurrent();
            current = await onFile(frame);
          } else {
            await onFrame(frame);
          }
        }
      }
    } finally {
      await closeCurrent();
      await input.close();
    }
  }

  static Future<(BackupHeader, EncodedHeader)> _header(
    RandomAccessFile input,
  ) async {
    final magic = await input.read(BackupFormat.magic.length);
    if (!_same(magic, BackupFormat.magic)) throw const BackupNotABackupError();
    final lengthBytes = await input.read(4);
    if (lengthBytes.length != 4) throw const BackupNotABackupError();
    final length = readU32(lengthBytes);
    if (length > BackupFormat.maxHeaderBytes) {
      throw const BackupNotABackupError();
    }
    final bytes = await input.read(length);
    if (bytes.length != length) throw const BackupNotABackupError();
    Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const BackupNotABackupError();
    }
    final header = BackupHeader.fromJson(json);
    if (header == null) throw const BackupNotABackupError();
    return (header, EncodedHeader(bytes));
  }

  /// Opened off the UI isolate by [BackupRecordWorker].
  static Future<(int, Uint8List)> _nextRecord(
    RandomAccessFile input,
    List<int> key,
    String digest,
    int index,
  ) async {
    final lengthBytes = await input.read(4);
    if (lengthBytes.length != 4) throw const BackupIncompleteError();
    final length = readU32(lengthBytes);
    if (length > BackupFormat.maxRecordBytes) throw const BackupDamagedError();
    final sealed = await input.read(length);
    if (sealed.length != length) throw const BackupIncompleteError();
    return BackupRecordWorker.open(
      key,
      BackupCrypto.recordAad(digest, index),
      sealed,
    );
  }

  /// One unreadable line is one lost row, never a lost restore: the record's
  /// tag already proved the bytes are ours.
  static Map<String, dynamic>? _frame(String line) {
    try {
      final json = jsonDecode(line);
      return json is Map ? Map<String, dynamic>.from(json) : null;
    } catch (_) {
      return null;
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
