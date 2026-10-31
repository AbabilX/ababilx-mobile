import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'backup_crypto.dart';
import 'backup_header.dart';
import 'backup_record_worker.dart';

/// Streams frames and files into one sealed backup file.
///
/// Memory is bounded by one record: frames buffer up to [frameRecordBytes] of
/// NDJSON before they are gzipped and sealed, and a file is read and sealed
/// [filePartBytes] at a time, so a phone with 200 000 messages and a thousand
/// photos costs the same peak as one with ten. Only ciphertext ever reaches
/// the disk. Each record is gzipped and sealed by [BackupRecordWorker], off
/// the UI isolate.
class BackupFileWriter {
  BackupFileWriter._(
    this._file,
    this._sink,
    this._key,
    this._digest, [
    this._drain = false,
  ]);

  static const frameRecordBytes = 256 * 1024;
  static const filePartBytes = 512 * 1024;

  static Future<BackupFileWriter> create(
    File file, {
    required List<int> accountKey,
    required String userId,
    required int createdAtMs,
  }) async {
    final sink = file.openWrite();
    final (key, digest) = await _start(sink, accountKey, userId, createdAtMs);
    return BackupFileWriter._(file, sink, key, digest);
  }

  /// The same stream written into [sink] instead of a file — Transfer chats
  /// sends it straight into an HTTP request. Each record waits for the sink
  /// to take it, so a slow network holds the export rather than memory.
  static Future<BackupFileWriter> toSink(
    IOSink sink, {
    required List<int> key,
    required String userId,
    required int createdAtMs,
  }) async {
    final (fileKey, digest) = await _start(sink, key, userId, createdAtMs);
    return BackupFileWriter._(null, sink, fileKey, digest, true);
  }

  static Future<(List<int>, String)> _start(
    IOSink sink,
    List<int> accountKey,
    String userId,
    int createdAtMs,
  ) async {
    final salt = BackupCrypto.randomBytes(BackupCrypto.saltBytes);
    final header = EncodedHeader.of(
      BackupHeader(
        userId: userId,
        salt: salt,
        keyCheck: await BackupCrypto.keyCheck(accountKey, salt),
        createdAtMs: createdAtMs,
      ),
    );
    sink
      ..add(BackupFormat.magic)
      ..add(u32(header.bytes.length))
      ..add(header.bytes);
    final key = await BackupCrypto.fileKey(accountKey, salt);
    return (await key.extractBytes(), header.digest);
  }

  final File? _file;
  final IOSink _sink;
  final bool _drain;
  final List<int> _key;
  final String _digest;
  final _frames = BytesBuilder(copy: false);
  int _index = 0;
  int _frameCount = 0;
  int _fileCount = 0;
  bool _closed = false;

  int get framesWritten => _frameCount;
  int get filesWritten => _fileCount;

  Future<void> addFrame(Map<String, dynamic> frame) =>
      addFrameJson(jsonEncode(frame));

  /// [addFrame] for a frame the caller already encoded as one JSON object
  /// (the backup's message rows, whose JSON it hashed anyway).
  Future<void> addFrameJson(String json) async {
    _frames.add(utf8.encode('$json\n'));
    _frameCount++;
    if (_frames.length >= frameRecordBytes) await _flushFrames();
  }

  /// A `file` frame followed by the file's bytes. The frame is flushed first
  /// so the reader meets it before the parts it names. Returns false, having
  /// written nothing, when the source cannot be read.
  Future<bool> addFile(Map<String, dynamic> frame, File source) async {
    RandomAccessFile? input;
    try {
      input = await source.open();
    } catch (_) {
      return false;
    }
    try {
      final size = await input.length();
      await addFrame({...frame, 't': 'file', 's': size});
      await _flushFrames();
      var left = size;
      while (left > 0) {
        final part = await input.read(
          left < filePartBytes ? left : filePartBytes,
        );
        if (part.isEmpty) break;
        await _record(BackupRecordType.filePart, part);
        left -= part.length;
      }
      _fileCount++;
      return true;
    } finally {
      await input.close();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    await _flushFrames();
    await _record(
      BackupRecordType.end,
      utf8.encode(jsonEncode({'frames': _frameCount, 'files': _fileCount})),
    );
    _closed = true;
    await _sink.flush();
    await _sink.close();
  }

  /// Stops and removes the partial file. A half-written backup must never sit
  /// where a restore could pick it up.
  Future<void> abort() async {
    if (!_closed) {
      _closed = true;
      try {
        await _sink.close();
      } catch (_) {}
    }
    final file = _file;
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _flushFrames() async {
    if (_frames.isEmpty) return;
    await _record(BackupRecordType.frames, _frames.takeBytes());
  }

  /// A frames [body] is raw NDJSON: the worker gzips it.
  Future<void> _record(int type, List<int> body) async {
    final sealed = await BackupRecordWorker.seal(
      _key,
      BackupCrypto.recordAad(_digest, _index),
      type,
      body,
    );
    _sink
      ..add(u32(sealed.length))
      ..add(sealed);
    _index++;
    if (_drain) await _sink.flush();
  }
}
