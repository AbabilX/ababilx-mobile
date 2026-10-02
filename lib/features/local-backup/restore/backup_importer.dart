import 'dart:io';

import '../../messages/data/models/chat_message.dart';
import '../format/backup_file_reader.dart';

class BackupRestoreStats {
  const BackupRestoreStats({required this.messages, required this.files});
  final int messages;
  final int files;
}

typedef AdoptRestoredFile =
    Future<void> Function({
      required String fileUrl,
      required String fileName,
      required String contentType,
      required File source,
    });

/// Replays a backup into this phone: messages into the store, readable text
/// into the restored-body table, files into the attachment store.
///
/// **Merge, never wipe** — the archive importer's rule, for its reason: rows
/// are written by id, so a second restore of the same file converges, and a
/// restore cut short can simply run again.
class BackupImporter {
  BackupImporter({
    required this.saveMessages,
    required this.saveBodies,
    required this.adoptFile,
    required this.tempDir,
    this.onOtherFrame,
    this.onOtherFile,
  });

  final Future<void> Function(List<ChatMessage> messages) saveMessages;
  final Future<void> Function(Map<String, String> bodies) saveBodies;
  final AdoptRestoredFile adoptFile;
  final Directory tempDir;

  /// Everything that is not a message (chat list, calls, settings) and every
  /// file that is not an attachment (`x` set: pictures). See
  /// `extras/backup_extras_restore.dart`.
  final Future<void> Function(Map<String, dynamic> frame)? onOtherFrame;
  final Future<BackupFileSink?> Function(Map<String, dynamic> frame)?
  onOtherFile;

  static const _batch = 200;

  Future<BackupRestoreStats> run(
    File backup,
    List<int> accountKey, {
    void Function(int messages)? onProgress,
    bool Function()? shouldContinue,
    void Function(int read, int total)? onBytes,
  }) async {
    final pending = <ChatMessage>[];
    final bodies = <String, String>{};
    var messages = 0;
    var files = 0;

    Future<void> flush() async {
      if (pending.isEmpty) return;
      await saveMessages(List.of(pending));
      if (bodies.isNotEmpty) await saveBodies(Map.of(bodies));
      messages += pending.length;
      pending.clear();
      bodies.clear();
      onProgress?.call(messages);
    }

    await tempDir.create(recursive: true);
    try {
      await BackupFileReader(backup, accountKey).run(
        shouldContinue: shouldContinue,
        onBytes: onBytes,
        onFrame: (frame) async {
          if (frame['t'] != 'msg') return onOtherFrame?.call(frame);
          if (frame['m'] is! Map) return;
          final ChatMessage message;
          try {
            message = ChatMessage.fromJson(
              Map<String, dynamic>.from(frame['m'] as Map),
            );
          } catch (_) {
            return; // one unreadable row, never a lost restore
          }
          if (message.id.isEmpty) return;
          pending.add(message);
          final text = frame['p'];
          if (text is String && message.isEncrypted) bodies[message.id] = text;
          if (pending.length >= _batch) await flush();
        },
        onFile: (frame) async {
          // A file's message is already in `pending`; flushing first keeps a
          // photo from landing in the store before the row that shows it.
          await flush();
          if (frame['x'] != null) return onOtherFile?.call(frame);
          final url = frame['u'];
          if (url is! String || url.isEmpty) return null;
          return _RestoredFileSink(
            File('${tempDir.path}/${files + 1}.part'),
            expectedBytes: (frame['s'] as num?)?.toInt() ?? -1,
            onDone: (file) async {
              await adoptFile(
                fileUrl: url,
                fileName: frame['n'] as String? ?? 'file',
                contentType:
                    frame['ct'] as String? ?? 'application/octet-stream',
                source: file,
              );
              files++;
            },
          );
        },
      );
      await flush();
    } finally {
      // Whatever landed stays: rows are merged by id and a rerun converges.
      await flush().catchError((_) {});
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
    return BackupRestoreStats(messages: messages, files: files);
  }
}

/// One file's bytes, written to a temp file and handed over only when
/// complete — a short file is dropped, never adopted as a broken photo.
class _RestoredFileSink implements BackupFileSink {
  _RestoredFileSink(
    this._file, {
    required this.expectedBytes,
    required this.onDone,
  }) : _sink = _file.openWrite();

  final File _file;
  final IOSink _sink;
  final int expectedBytes;
  final Future<void> Function(File file) onDone;
  int _written = 0;

  @override
  Future<void> add(List<int> bytes) async {
    _sink.add(bytes);
    _written += bytes.length;
  }

  @override
  Future<void> close() async {
    await _sink.close();
    try {
      if (expectedBytes < 0 || _written == expectedBytes) await onDone(_file);
    } finally {
      try {
        await _file.delete();
      } catch (_) {}
    }
  }
}
