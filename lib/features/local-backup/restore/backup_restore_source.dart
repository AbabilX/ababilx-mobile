import '../auto/account_backup_dir.dart';
import '../platform/backup_folder_channel.dart';

/// One file a restore reads: a path this app can open directly, or a
/// document in a granted folder that has to be copied into the cache first.
class BackupSourceFile {
  const BackupSourceFile.local(String this.path, this.bytes) : uri = null;
  const BackupSourceFile.document(String this.uri, this.bytes) : path = null;

  final String? path;
  final String? uri;
  final int bytes;
}

/// Everything one restore reads: the messages file, then the media files the
/// automatic backup keeps beside it (none for a single-file backup).
class BackupRestoreSource {
  const BackupRestoreSource({
    required this.main,
    this.media = const [],
    this.createdAtMs,
  });

  final BackupSourceFile main;
  final List<BackupSourceFile> media;

  /// When the backup was written, for "a backup from yesterday" on screen.
  final int? createdAtMs;

  int get bytes => media.fold(main.bytes, (sum, file) => sum + file.bytes);
}

/// The backups in the automatic folder that this install can read, newest
/// first. Empty after a reinstall: Android hides the old files until the
/// folder is granted again.
Future<List<BackupRestoreSource>> accountDirSources(
  AccountBackupDir dir,
) async {
  final backups = await dir.backups();
  if (backups.isEmpty) return const [];
  final media = [
    for (final file in await dir.mediaFiles())
      BackupSourceFile.local(file.path, await file.length()),
  ];
  return [
    for (final backup in backups)
      BackupRestoreSource(
        main: BackupSourceFile.local(backup.path, await backup.length()),
        media: media,
        createdAtMs: (await backup.lastModified()).millisecondsSinceEpoch,
      ),
  ];
}

/// What a granted folder holds for [userId].
class GrantedFolderBackups {
  const GrantedFolderBackups({
    required this.entries,
    required this.media,
    required this.accountLayout,
  });

  /// Backup files, newest first, whichever account wrote them.
  final List<BackupFolderEntry> entries;
  final List<BackupSourceFile> media;

  /// True when the files came from `<account id>/` — the automatic backup's
  /// layout — so the newest one of this account can be taken without asking.
  final bool accountLayout;

  BackupRestoreSource sourceFor(BackupFolderEntry entry) => BackupRestoreSource(
    main: BackupSourceFile.document(entry.uri, entry.bytes),
    media: media,
    createdAtMs: entry.modifiedMs,
  );
}

/// The backups of [userId] in a granted folder, newest first, with nothing
/// asked: for a restore the person already agreed to.
Future<List<BackupRestoreSource>> grantedBackupSources(
  BackupFolderChannel channel,
  String folderUri,
  String userId,
) async {
  final found = await readGrantedFolder(channel, folderUri, userId);
  return [
    for (final entry in found.entries)
      if (entry.owner == userId) found.sourceFor(entry),
  ];
}

/// Reads a granted folder. The person may have granted `Documents/AbabilX`
/// (the account folder is one level down) or the account folder itself, or a
/// folder of single-file backups they picked long ago — all three are read.
Future<GrantedFolderBackups> readGrantedFolder(
  BackupFolderChannel channel,
  String folderUri,
  String userId,
) async {
  var level = await channel.children(folderUri);
  var accountLayout = false;
  // Documents itself was granted: the backups are one folder further down.
  final home = level.where((e) => e.isDir && e.name == 'AbabilX').firstOrNull;
  if (home != null && !level.any((e) => e.isDir && e.name == userId)) {
    level = await channel.children(folderUri, parent: home.documentId);
  }
  final own = level.where((e) => e.isDir && e.name == userId).firstOrNull;
  if (own != null) {
    level = await channel.children(folderUri, parent: own.documentId);
    accountLayout = true;
  }
  final mediaDir = level.where((e) => e.isDir && e.name == 'media').firstOrNull;
  final media = mediaDir == null
      ? const <BackupFolderEntry>[]
      : await channel.children(folderUri, parent: mediaDir.documentId);
  final entries = level.where((e) => e.isBackup).toList()
    ..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  return GrantedFolderBackups(
    entries: entries,
    accountLayout: accountLayout || mediaDir != null,
    media: [
      for (final file in media)
        if (!file.isDir && file.name.endsWith(AccountBackupDir.mediaExtension))
          BackupSourceFile.document(file.uri, file.bytes),
    ],
  );
}
