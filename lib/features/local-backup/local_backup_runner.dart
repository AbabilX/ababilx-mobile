import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../attachments/data/models/attachment_url_key.dart';
import '../attachments/providers/attachment_providers.dart';
import '../messages/data/local/chat_deletion_sync.dart';
import '../messages/data/local/chat_message_store.dart';
import '../messages/data/local/chat_sidebar_cache.dart';
import '../messages/data/models/chat_conversation.dart';
import '../messages/message_e2ee/message_vault.dart';
import '../messages/providers/chat_provider.dart';
import '../profile/providers/profile_provider.dart';
import 'data/backup_file_name.dart';
import 'data/backup_key_store.dart';
import 'data/local_backup_failure.dart';
import 'data/local_backup_settings.dart';
import 'export/backup_exporter.dart';
import 'format/backup_errors.dart';
import 'local_backup_extras.dart';
import 'format/backup_file_reader.dart';
import 'format/backup_file_writer.dart';
import 'platform/backup_folder_channel.dart';
import 'restore/backup_importer.dart';
import 'restore/restored_body_store.dart';

export 'data/backup_file_name.dart';

/// Wires the pure pieces (exporter, importer, format) to this app's store,
/// vault, attachments and the picked folder. Holds no state of its own.
class LocalBackupRunner {
  LocalBackupRunner(this._ref);

  final Ref _ref;
  static const folder = BackupFolderChannel();

  Future<Directory> _work(String name) async =>
      Directory('${(await getTemporaryDirectory()).path}/local-backup/$name');

  Future<(BackupFolderEntry, BackupExportStats)> backUp({
    required String userId,
    required LocalBackupSettings settings,
    void Function(int messages)? onProgress,
    bool Function()? shouldContinue,
  }) async {
    final folderUri = settings.folderUri;
    if (folderUri == null || folderUri.isEmpty) {
      throw LocalBackupFailure.noFolder;
    }
    if (!settings.choices.anyChats) throw LocalBackupFailure.nothingSelected;
    final vault = _ref.read(messageVaultProvider);
    if (!vault.isUnlocked) throw LocalBackupFailure.locked;
    if (!await folder.hasAccess(folderUri)) throw LocalBackupFailure.folderLost;
    final key = await _ref.read(backupKeyStoreProvider).keyFor(userId);
    await syncChatDeletions(_ref, userId);

    final store = _ref.read(chatMessageStoreProvider);
    final blobs = _ref.read(attachmentBlobStoreProvider);
    final now = DateTime.now();
    final username = _ref.read(profileProvider).valueOrNull?.username ?? '';
    final name = backupFileName(username, now);
    final dir = await _work('out');
    await dir.create(recursive: true);
    final temp = File('${dir.path}/$name');
    final writer = await BackupFileWriter.create(
      temp,
      accountKey: key,
      userId: userId,
      createdAtMs: now.millisecondsSinceEpoch,
    );
    try {
      // Calls, settings and pictures first: a restore cut short has them.
      final extras = await LocalBackupExtras(_ref).write(writer);
      debugPrint(
        '[LocalBackup] export extras: calls=${extras.calls} '
        'settings=${extras.settings} pictures=${extras.pictures}',
      );
      final stats = await BackupExporter(
        readPage: (afterMs, afterId) =>
            store.exportPage(afterMs: afterMs, afterId: afterId, limit: 500),
        allows: store.deletions.allows,
        openBody: (m) => vault.openBodyForBackup(m, userId),
        localFile: (url) async {
          final row = await blobs.read(attachmentUrlKey(url));
          final path = row?.localPath;
          if (path == null || path.isEmpty) return null;
          final file = File(path);
          return await file.exists() ? file : null;
        },
        choices: settings.choices,
        conversations: await _conversations(userId),
      ).run(writer, onProgress: onProgress, shouldContinue: shouldContinue);
      await writer.close();
      debugPrint(
        '[LocalBackup] export: messages=${stats.messages} '
        'files=${stats.files} unreadable=${stats.unreadable} '
        'bytes=${await temp.length()}',
      );
      final entry = await folder.write(
        folderUri: folderUri,
        sourcePath: temp.path,
        name: name,
        owner: userId,
      );
      return (entry, stats);
    } catch (_) {
      await writer.abort();
      rethrow;
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }

  /// The chats a message's kind is read from. The live list, else the sidebar
  /// cache: an unknown chat counts as a group, so reading neither would file
  /// every DM under "Groups" and miss every private chat's switch.
  Future<Map<String, ChatConversation>> _conversations(String userId) async {
    final chat = _ref.read(chatProvider);
    var all = [...chat.channels, ...chat.dms];
    if (all.isEmpty) {
      try {
        final cached = await ChatSidebarCache(
          _ref.read(chatLocalDbProvider),
        ).read(userId);
        if (cached != null) all = [...cached.channels, ...cached.dms];
      } catch (_) {}
    }
    return {for (final c in all) c.id: c};
  }

  /// Restores [documentUri] (a file in the folder, or one picked from
  /// anywhere) into this account. Refuses another account's file before it
  /// asks the server for anything.
  Future<BackupRestoreStats> restore({
    required String userId,
    required String documentUri,
    void Function(int messages)? onProgress,
    void Function(int read, int total)? onBytes,
    bool Function()? shouldContinue,
  }) async {
    final dir = await _work('in');
    await dir.create(recursive: true);
    final temp = File('${dir.path}/restore.abxbackup');
    try {
      await folder.copyToCache(documentUri, temp.path);
      final header = await BackupFileReader.readHeader(temp);
      debugPrint(
        '[LocalBackup] restore: file=${await temp.length()}B '
        'owner=${header.userId} me=$userId',
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
      final stats =
          await BackupImporter(
            saveMessages: (m) => store.saveRecovered(m, fromBackup: true),
            saveBodies: (b) => bodies.putAll(userId, b),
            adoptFile: adopter.adoptFile,
            tempDir: Directory('${dir.path}/files'),
            onOtherFrame: collected.onFrame,
            onOtherFile: collected.onFile,
          ).run(
            temp,
            key,
            onProgress: onProgress,
            onBytes: onBytes,
            shouldContinue: shouldContinue,
          );
      // Chat list, calls, settings and pictures: works offline from here on.
      await extras.apply(collected, userId);
      // Chats already opened this session read their pages again from disk.
      final chat = _ref.read(chatProvider.notifier)..resetFeedHydration();
      // The list reads its previews from the phone where the server has none.
      unawaited(chat.fetchSidebarSilent().catchError((_) {}));
      debugPrint(
        '[LocalBackup] restore done: messages=${stats.messages} '
        'files=${stats.files}',
      );
      return stats;
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }
}
