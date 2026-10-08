import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../attachments/providers/attachment_providers.dart';
import '../messages/data/local/chat_deletion_sync.dart';
import '../messages/data/local/chat_message_store.dart';
import '../messages/providers/chat_provider.dart';
import 'data/backup_key_store.dart';
import 'format/backup_errors.dart';
import 'format/backup_file_reader.dart';
import 'local_backup_extras.dart';
import 'platform/backup_folder_channel.dart';
import 'restore/backup_importer.dart';
import 'restore/backup_restore_source.dart';
import 'restore/restored_body_store.dart';

/// Replays a backup into this account: the messages file first, then each
/// media file kept beside it. Refuses another account's file before it asks
/// the server for anything.
class LocalBackupRestoreRunner {
  LocalBackupRestoreRunner(this._ref);

  final Ref _ref;
  static const _folder = BackupFolderChannel();

  Future<BackupRestoreStats> restore({
    required String userId,
    required BackupRestoreSource source,
    void Function(int messages)? onProgress,
    void Function(int read, int total)? onBytes,
    bool Function()? shouldContinue,
  }) async {
    final cache = (await getTemporaryDirectory()).path;
    final dir = Directory('$cache/local-backup/in');
    await dir.create(recursive: true);
    final temp = File('${dir.path}/restore.abxbackup');
    try {
      final main = await _open(source.main, temp);
      final header = await BackupFileReader.readHeader(main);
      debugPrint(
        '[LocalBackup] restore: file=${source.main.bytes}B '
        'media=${source.media.length} owner=${header.userId} me=$userId',
      );
      if (header.userId != userId) throw const BackupWrongAccountError();
      final key = await _ref.read(backupKeyStoreProvider).keyFor(userId);
      await syncChatDeletions(_ref, userId);
      final store = _ref.read(chatMessageStoreProvider);
      // A fresh start marks every chat "history before now is gone", and the
      // whole backup is older than that — the case it exists for. Deletes
      // still hold; only the watermark is looked past, on this device.
      await store.deletions.admitRestoredHistory();
      final bodies = _ref.read(restoredBodyStoreProvider);
      final adopter = _ref.read(attachmentAdopterProvider);
      final extras = LocalBackupExtras(_ref);
      final collected = await extras.collector();
      final total = source.bytes;
      var before = 0;
      BackupImporter importer({bool others = true}) => BackupImporter(
        saveMessages: (m) => store.saveRecovered(m, fromBackup: true),
        saveBodies: (b) => bodies.putAll(userId, b),
        adoptFile: adopter.adoptFile,
        tempDir: Directory('${dir.path}/files'),
        onOtherFrame: others ? collected.onFrame : null,
        onOtherFile: others ? collected.onFile : null,
      );
      final stats = await importer().run(
        main,
        key,
        onProgress: onProgress,
        onBytes: (read, _) => onBytes?.call(read, total),
        shouldContinue: shouldContinue,
      );
      before = source.main.bytes;
      // Chat list, calls, settings and pictures: works offline from here on.
      await extras.apply(collected, userId);
      // Chats already opened this session read their pages again from disk.
      final chat = _ref.read(chatProvider.notifier)..resetFeedHydration();
      // The list reads its previews from the phone where the server has none.
      unawaited(chat.fetchSidebarSilent().catchError((_) {}));

      var files = stats.files;
      for (final item in source.media) {
        if (shouldContinue?.call() == false) throw const BackupCancelledError();
        final offset = before;
        try {
          final file = await _open(item, temp);
          final one = await importer(others: false).run(
            file,
            key,
            onBytes: (read, _) => onBytes?.call(offset + read, total),
            shouldContinue: shouldContinue,
          );
          files += one.files;
        } on BackupCancelledError {
          rethrow;
        } catch (error) {
          // One unreadable media file is one missing photo, never a failed
          // restore: the messages are already back.
          debugPrint('[LocalBackup] restore: media skipped: $error');
        }
        before += item.bytes;
        onBytes?.call(before, total);
      }
      debugPrint(
        '[LocalBackup] restore done: messages=${stats.messages} files=$files',
      );
      return BackupRestoreStats(messages: stats.messages, files: files);
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }

  /// A local path is read where it lies; a document is copied into the cache
  /// (the reader needs random access, which a content URI does not give).
  Future<File> _open(BackupSourceFile source, File temp) async {
    final path = source.path;
    if (path != null) return File(path);
    await _folder.copyToCache(source.uri!, temp.path);
    return temp;
  }
}
