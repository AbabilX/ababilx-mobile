import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../attachments/providers/attachment_providers.dart';
import '../local-backup/data/backup_choices.dart';
import '../local-backup/export/backup_exporter.dart';
import '../local-backup/format/backup_errors.dart';
import '../local-backup/format/backup_file_reader.dart';
import '../local-backup/format/backup_file_writer.dart';
import '../local-backup/local_backup_extras.dart';
import '../local-backup/local_backup_runner.dart';
import '../local-backup/restore/backup_importer.dart';
import '../local-backup/restore/restored_body_store.dart';
import '../messages/data/local/chat_archive_wiper.dart';
import '../messages/data/local/chat_deletion_sync.dart';
import '../messages/data/local/chat_message_store.dart';
import '../messages/message_e2ee/message_vault.dart';
import '../messages/providers/chat_provider.dart';

/// Transfer chats is a local backup that never touches a folder: the old
/// device writes the backup stream into the network, the new one reads it
/// back with the restore code. Same frames, same records, same merge — only
/// the key differs: the code's secret, not the account's backup key, so the
/// server holds nothing that opens it.
class TransferChatsService {
  TransferChatsService(this._ref);

  final Ref _ref;

  /// Old device: every chat and every file on disk, into [sink]. Media of
  /// every kind goes, whatever the local backup's own choices say.
  Future<BackupExportStats> export(
    IOSink sink, {
    required String userId,
    required List<int> secret,
    BackupProgress? onProgress,
    bool Function()? shouldContinue,
  }) async {
    final vault = _ref.read(messageVaultProvider);
    final runner = LocalBackupRunner(_ref);
    final extras = LocalBackupExtras(_ref);
    // The call log pages from the server while the deletions sync.
    final calls = extras.allCalls();
    unawaited(calls.then((_) {}, onError: (_) {}));
    // A chat deleted on another device must not travel from this one.
    await syncChatDeletions(_ref, userId);
    final store = _ref.read(chatMessageStoreProvider);
    final writer = await BackupFileWriter.toSink(
      sink,
      key: secret,
      userId: userId,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    // Calls, settings and pictures first, as the backup does.
    await extras.write(writer, calls: await calls);
    final stats = await BackupExporter(
      readPage: (afterMs, afterId) =>
          store.exportPage(afterMs: afterMs, afterId: afterId, limit: 500),
      allows: store.deletions.allows,
      openBody: vault.backupBodyOpener(userId),
      localFile: runner.localFile,
      choices: const BackupChoices(),
      conversations: await runner.conversations(userId),
    ).run(writer, onProgress: onProgress, shouldContinue: shouldContinue);
    await writer.close();
    return stats;
  }

  /// New device: replays a received stream into this account. Refuses
  /// another account's stream before anything is written.
  Future<BackupRestoreStats> import(
    File file, {
    required String userId,
    required List<int> secret,
    void Function(int messages)? onProgress,
  }) async {
    final header = await BackupFileReader.readHeader(file);
    if (header.userId != userId) throw const BackupWrongAccountError();
    await syncChatDeletions(_ref, userId);
    final store = _ref.read(chatMessageStoreProvider);
    await store.deletions.admitRestoredHistory();
    final bodies = _ref.read(restoredBodyStoreProvider);
    final adopter = _ref.read(attachmentAdopterProvider);
    final extras = LocalBackupExtras(_ref);
    final collected = await extras.collector();
    final temp = (await getTemporaryDirectory()).path;
    final stats = await BackupImporter(
      saveMessages: (m) => store.saveRecovered(m, fromBackup: true),
      saveBodies: (b) => bodies.putAll(userId, b),
      adoptFile: adopter.adoptFile,
      holdsFile: adopter.holds,
      tempDir: Directory('$temp/transfer-chats/files'),
      onOtherFrame: collected.onFrame,
      onOtherFile: collected.onFile,
    ).run(file, secret, onProgress: onProgress);
    // Chat list, calls, settings and pictures.
    await extras.apply(collected, userId);
    final chat = _ref.read(chatProvider.notifier)..resetFeedHydration();
    await chat.adoptRestoredBackup();
    unawaited(chat.fetchSidebarSilent().catchError((_) {}));
    return stats;
  }

  /// Old device, after a finished transfer, when the user asks: every chat's
  /// messages and files leave this phone. The account stays signed in and
  /// the chat list comes back from the server, empty of history.
  Future<void> wipeThisPhone() async {
    await _ref.read(chatArchiveWiperProvider).clear();
    await _ref.read(chatProvider.notifier).fetchSidebarSilent();
  }
}

final transferChatsServiceProvider = Provider<TransferChatsService>(
  TransferChatsService.new,
);
