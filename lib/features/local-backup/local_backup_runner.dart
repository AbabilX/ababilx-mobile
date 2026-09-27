import 'dart:io';

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
import 'data/backup_key_store.dart';
import 'data/local_backup_failure.dart';
import 'data/local_backup_settings.dart';
import 'export/backup_exporter.dart';
import 'format/backup_errors.dart';
import 'format/backup_file_reader.dart';
import 'format/backup_file_writer.dart';
import 'platform/backup_folder_channel.dart';
import 'restore/backup_importer.dart';
import 'restore/restored_body_store.dart';

/// `AbabilX-<8 chars of the account id>-` — every file one account writes
/// starts with it, so pruning never touches another account's backups in a
/// shared folder.
String backupTag(String userId) =>
    'AbabilX-${userId.replaceAll('-', '').padRight(8, '0').substring(0, 8)}-';

String backupFileName(String userId, DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
  return '${backupTag(userId)}$stamp.abxbackup';
}

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
    final name = backupFileName(userId, now);
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
      final entry = await folder.write(
        folderUri: folderUri,
        sourcePath: temp.path,
        name: name,
        tag: backupTag(userId),
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
    bool Function()? shouldContinue,
  }) async {
    final dir = await _work('in');
    await dir.create(recursive: true);
    final temp = File('${dir.path}/restore.abxbackup');
    try {
      await folder.copyToCache(documentUri, temp.path);
      final header = await BackupFileReader.readHeader(temp);
      if (header.userId != userId) throw const BackupWrongAccountError();
      final key = await _ref.read(backupKeyStoreProvider).keyFor(userId);
      await syncChatDeletions(_ref, userId);
      final store = _ref.read(chatMessageStoreProvider);
      final bodies = _ref.read(restoredBodyStoreProvider);
      final adopter = _ref.read(attachmentAdopterProvider);
      final stats = await BackupImporter(
        saveMessages: (m) => store.saveRecovered(m, fromBackup: true),
        saveBodies: (b) => bodies.putAll(userId, b),
        adoptFile: adopter.adoptFile,
        tempDir: Directory('${dir.path}/files'),
      ).run(temp, key, onProgress: onProgress, shouldContinue: shouldContinue);
      // Chats already opened this session read their pages again from disk.
      _ref.read(chatProvider.notifier).resetFeedHydration();
      return stats;
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }
}
