import 'package:flutter/services.dart';

/// A backup file as the folder lists it.
class BackupFolderEntry {
  const BackupFolderEntry({
    required this.uri,
    required this.name,
    required this.bytes,
    required this.modifiedMs,
    this.owner,
    this.isDir = false,
    this.documentId,
  });

  final String uri;
  final String name;
  final int bytes;
  final int modifiedMs;

  /// Account id from the file's header; null when it is not a backup.
  final String? owner;

  /// Set by [BackupFolderChannel.children], which also lists folders.
  final bool isDir;
  final String? documentId;

  bool get isBackup => !isDir && name.endsWith('.abxbackup');
  bool get isPartial => name.endsWith('.partial');

  factory BackupFolderEntry.fromMap(Map<dynamic, dynamic> map) =>
      BackupFolderEntry(
        uri: map['uri'] as String? ?? '',
        name: map['name'] as String? ?? '',
        bytes: (map['bytes'] as num?)?.toInt() ?? 0,
        modifiedMs: (map['modifiedMs'] as num?)?.toInt() ?? 0,
        owner: map['owner'] as String?,
        isDir: map['dir'] == true,
        documentId: map['id'] as String?,
      );
}

class PickedFolder {
  const PickedFolder(this.uri, this.label, {this.writable = true});
  final String uri;
  final String? label;

  /// A backup could actually be created there. False for Android's media
  /// folders (Recordings, Music, Pictures…), which refuse other file types.
  final bool writable;
}

/// The automatic backup's own folder (Kotlin `BackupDefaultFolder`).
class DefaultBackupFolder {
  const DefaultBackupFolder({
    required this.path,
    required this.freeBytes,
    required this.isPublic,
  });

  final String path;
  final int freeBytes;

  /// True for `Documents/AbabilX`, which outlives an uninstall; false for the
  /// app's own folder (Android 10 and below), which does not.
  final bool isPublic;
}

/// Dart half of `com.ababilx.app/local_backup` (Kotlin `LocalBackupChannel`).
/// Moves sealed files in and out of the picked folder; holds no key.
class BackupFolderChannel {
  const BackupFolderChannel();

  static const _channel = MethodChannel('com.ababilx.app/local_backup');

  /// The system folder picker. Null when the person backed out.
  /// [atBackups] opens it on the automatic backup's own folder.
  Future<PickedFolder?> pickFolder({bool atBackups = false}) async {
    final map = await _channel.invokeMapMethod<String, dynamic>('pickFolder', {
      'start': atBackups ? 'backups' : 'documents',
    });
    if (map == null) return null;
    return PickedFolder(
      map['uri'] as String,
      map['label'] as String?,
      writable: map['writable'] != false,
    );
  }

  /// The system file picker, for a backup carried over from another phone.
  Future<BackupFolderEntry?> pickFile() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('pickFile');
    return map == null ? null : BackupFolderEntry.fromMap(map);
  }

  /// Whether this install still holds the folder grant. A reinstall keeps the
  /// folder and loses the grant, which is when the screen asks to pick again.
  Future<bool> hasAccess(String folderUri) async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'folderStatus',
      {'uri': folderUri},
    );
    return map?['access'] == true;
  }

  Future<List<BackupFolderEntry>> list(String folderUri) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'listBackups',
      {'uri': folderUri},
    );
    return [
      for (final row in rows ?? const <Map<dynamic, dynamic>>[])
        BackupFolderEntry.fromMap(row),
    ].where((e) => !e.isPartial).toList();
  }

  /// One level of a granted folder: files and folders, partials included.
  Future<List<BackupFolderEntry>> children(
    String folderUri, {
    String? parent,
  }) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'listChildren',
      {'uri': folderUri, 'parent': parent},
    );
    return [
      for (final row in rows ?? const <Map<dynamic, dynamic>>[])
        BackupFolderEntry.fromMap(row),
    ];
  }

  /// Where the automatic backup goes when no folder was picked.
  Future<DefaultBackupFolder> defaultFolder() async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'defaultFolder',
    );
    return DefaultBackupFolder(
      path: map?['path'] as String? ?? '',
      freeBytes: (map?['free'] as num?)?.toInt() ?? 0,
      isPublic: map?['public'] == true,
    );
  }

  /// Copies a finished file in, then keeps this [owner]'s newest [keep].
  Future<BackupFolderEntry> write({
    required String folderUri,
    required String sourcePath,
    required String name,
    required String owner,
    int keep = 2,
  }) async {
    final map = await _channel.invokeMapMethod<String, dynamic>('writeBackup', {
      'uri': folderUri,
      'source': sourcePath,
      'name': name,
      'owner': owner,
      'keep': keep,
    });
    return BackupFolderEntry.fromMap(map ?? const {});
  }

  Future<int> copyToCache(String documentUri, String destPath) async =>
      await _channel.invokeMethod<int>('copyToCache', {
        'uri': documentUri,
        'dest': destPath,
      }) ??
      0;

  Future<void> releaseFolder(String folderUri) =>
      _channel.invokeMethod<void>('releaseFolder', {'uri': folderUri});
}
