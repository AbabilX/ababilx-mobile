import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../attachments/providers/attachment_providers.dart';
import '../messages/data/local/chat_deletion_sync.dart';
import '../messages/data/local/chat_message_store.dart';
import '../messages/providers/chat_provider.dart';
import 'auto/backup_message_segments.dart';
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
      var total = source.bytes;
      var before = 0;
      // The message weeks the main file lists (automatic folder): read next,
      // newest first. Every other frame is the chat list, calls, settings.
      final weeks = <String>[];
      Future<void> other(Map<String, dynamic> frame) async {
        final name = frame['n'];
        if (frame['t'] == 'seg') {
          if (name is String && name.isNotEmpty) weeks.add(name);
          return;
        }
        await collected.onFrame(frame);
      }

      BackupImporter importer({bool others = true}) => BackupImporter(
        saveMessages: (m) => store.saveRecovered(m, fromBackup: true),
        saveBodies: (b) => bodies.putAll(userId, b),
        adoptFile: adopter.adoptFile,
        holdsFile: adopter.holds,
        tempDir: Directory('${dir.path}/files'),
        onOtherFrame: others ? other : null,
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
      final rest = restoreReadOrder(source.media, weeks);
      total = rest.fold(before, (sum, file) => sum + file.bytes);
      final found = rest
          .where((f) => BackupMessageSegments.isSegmentName(f.name))
          .length;
      if (found < weeks.length) {
        // A listed week this install cannot see: its messages are missing.
        debugPrint(
          '[LocalBackup] restore: ${weeks.length - found} of '
          '${weeks.length} weeks not found',
        );
      }
      // Chat list, calls, settings and pictures: works offline from here on.
      await extras.apply(collected, userId);
      // Chats already opened this session read their pages again from disk.
      final chat = _ref.read(chatProvider.notifier)..resetFeedHydration();
      // The list reads its previews from the phone where the server has none.
      unawaited(chat.fetchSidebarSilent().catchError((_) {}));

      var files = stats.files;
      var messages = stats.messages;
      for (final item in rest) {
        if (shouldContinue?.call() == false) throw const BackupCancelledError();
        final offset = before;
        final counted = messages;
        try {
          final file = await _open(item, temp);
          final one = await importer(others: false).run(
            file,
            key,
            onProgress: (n) => onProgress?.call(counted + n),
            onBytes: (read, _) => onBytes?.call(offset + read, total),
            shouldContinue: shouldContinue,
          );
          files += one.files;
          messages += one.messages;
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
      // The weeks landed after the first refresh above: chats read their
      // pages from disk again, and previews follow the newest restored text.
      await chat.adoptRestoredBackup();
      unawaited(chat.fetchSidebarSilent().catchError((_) {}));
      debugPrint(
        '[LocalBackup] restore done: messages=$messages files=$files '
        'weeks=${weeks.length}',
      );
      return BackupRestoreStats(messages: messages, files: files);
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
