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
import 'auto/account_backup_dir.dart';
import 'auto/backup_media_store.dart';
import 'data/backup_file_name.dart';
import 'data/backup_key_store.dart';
import 'data/local_backup_failure.dart';
import 'data/local_backup_settings.dart';
import 'export/backup_exporter.dart';
import 'local_backup_extras.dart';
import 'format/backup_file_writer.dart';
import 'platform/backup_folder_channel.dart';

export 'data/backup_file_name.dart';

/// Wires the exporter to this app's store, vault and attachments, and to
/// where the backup goes: the folder the person picked (one whole file, as
/// before) or, with none picked, the automatic folder (messages rewritten,
/// each media file stored once). Holds no state of its own. Restoring is
/// `LocalBackupRestoreRunner`.
class LocalBackupRunner {
  LocalBackupRunner(this._ref);

  final Ref _ref;
  static const folder = BackupFolderChannel();

  Future<Directory> _work(String name) async =>
      Directory('${(await getTemporaryDirectory()).path}/local-backup/$name');

  /// This account's corner of the automatic folder, and the free space there.
  Future<(AccountBackupDir, int)> accountDir(String userId) async {
    final home = await folder.defaultFolder();
    if (home.path.isEmpty) throw LocalBackupFailure.noFolder;
    return (AccountBackupDir(Directory(home.path), userId), home.freeBytes);
  }

  Future<(BackupFolderEntry, BackupExportStats)> backUp({
    required String userId,
    required LocalBackupSettings settings,
    void Function(int messages)? onProgress,
    bool Function()? shouldContinue,
  }) async {
    final folderUri = settings.folderUri ?? '';
    final picked = folderUri.isNotEmpty;
    if (!settings.choices.anyChats) throw LocalBackupFailure.nothingSelected;
    final vault = _ref.read(messageVaultProvider);
    if (!vault.isUnlocked) throw LocalBackupFailure.locked;
    if (picked && !await folder.hasAccess(folderUri)) {
      throw LocalBackupFailure.folderLost;
    }
    final key = await _ref.read(backupKeyStoreProvider).keyFor(userId);
    await syncChatDeletions(_ref, userId);

    final store = _ref.read(chatMessageStoreProvider);
    final blobs = _ref.read(attachmentBlobStoreProvider);
    final now = DateTime.now();
    final username = _ref.read(profileProvider).valueOrNull?.username ?? '';
    final name = backupFileName(username, now);
    AccountBackupDir? account;
    BackupMediaStore? media;
    final File temp;
    if (picked) {
      final dir = await _work('out');
      await dir.create(recursive: true);
      temp = File('${dir.path}/$name');
    } else {
      final (dir, free) = await accountDir(userId);
      account = dir;
      media = BackupMediaStore(
        dir: dir.media,
        accountKey: key,
        userId: userId,
        freeBytes: free,
      );
      temp = await dir.partial(name);
    }
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
        media: media,
      ).run(writer, onProgress: onProgress, shouldContinue: shouldContinue);
      await writer.close();
      debugPrint(
        '[LocalBackup] export: messages=${stats.messages} '
        'files=${stats.files} unreadable=${stats.unreadable} '
        'bytes=${await temp.length()} newMedia=${media?.written} '
        'noSpace=${media?.skippedForSpace}',
      );
      if (account == null || media == null) {
        final entry = await folder.write(
          folderUri: folderUri,
          sourcePath: temp.path,
          name: name,
          owner: userId,
        );
        return (entry, stats);
      }
      final done = await account.commit(temp, name, media.wanted);
      final entry = BackupFolderEntry(
        uri: done.path,
        name: name,
        bytes: await account.size(),
        modifiedMs: now.millisecondsSinceEpoch,
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
}
