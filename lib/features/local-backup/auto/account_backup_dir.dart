import 'dart:io';

import 'package:flutter/foundation.dart';

import '../format/backup_file_reader.dart';
import '../format/backup_header.dart';

/// One account's corner of the automatic backup folder:
///
/// ```
/// <base>/<account id>/
///   <name>.abxbackup          messages, chats, calls, settings (rewritten)
///   <name>.abxbackup.media    the media names that backup refers to
///   media/<hash>.abxmedia     one sealed file per attachment (written once)
/// ```
///
/// Plain file paths, no picker: the app owns what it wrote here. A folder per
/// account, so two people signed in on one phone never share a listing, and
/// "is there a backup for this account" is one directory to look in.
class AccountBackupDir {
  AccountBackupDir(Directory base, this.userId)
    : root = Directory('${base.path}/$userId');

  static const mediaExtension = '.abxmedia';
  static const _partial = '.partial';
  static const _refs = refsExtension;

  /// Beside each backup: the media names it refers to, one per line.
  static const refsExtension = '.media';

  final String userId;
  final Directory root;

  Directory get media => Directory('${root.path}/media');

  /// Where a run writes before [commit]. Never listed as a backup. A partial
  /// left by a run the phone cut short is cleared first.
  Future<File> partial(String name) async {
    await root.create(recursive: true);
    await for (final entry in root.list(followLinks: false)) {
      if (entry is File && entry.path.endsWith(_partial)) await _remove(entry);
    }
    return File('${root.path}/$name$_partial');
  }

  /// This account's complete backups, newest first. The header decides whose
  /// a file is — never the folder it sits in.
  Future<List<File>> backups() async {
    if (!await root.exists()) return const [];
    final found = <(File, int)>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith(BackupFormat.extension)) {
        continue;
      }
      try {
        final header = await BackupFileReader.readHeader(entry);
        if (header.userId == userId) found.add((entry, header.createdAtMs));
      } catch (_) {}
    }
    found.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final item in found) item.$1];
  }

  /// Every media file held here, whichever backup refers to it.
  Future<List<File>> mediaFiles() async {
    if (!await media.exists()) return const [];
    return [
      await for (final entry in media.list(followLinks: false))
        if (entry is File && entry.path.endsWith(mediaExtension)) entry,
    ];
  }

  /// Makes [partial] the newest backup, then keeps the newest [keep] and only
  /// the media one of them still refers to. The old backups go only after the
  /// new one is whole.
  ///
  /// The media list is written before the backup takes its name: a phone cut
  /// off between the two leaves a list with no backup (cleared below, next
  /// time), never a backup with no list — which would stop all pruning.
  Future<File> commit(
    File partial,
    String name,
    Set<String> mediaNames, {
    int keep = 2,
  }) async {
    final target = '${root.path}/$name';
    await File(
      '$target$_refs',
    ).writeAsString(mediaNames.join('\n'), flush: true);
    final done = await partial.rename(target);
    final all = await backups();
    var removed = 0;
    for (final old in all.skip(keep)) {
      if (await _remove(old)) removed++;
      await _remove(File('${old.path}$_refs'));
    }
    await _clearStrayLists();
    final media = await _pruneMedia(all.take(keep).toList());
    debugPrint(
      '[LocalBackup] commit: backups=${all.length} removed=$removed '
      'mediaRemoved=$media',
    );
    return done;
  }

  /// `.media` lists whose backup is gone (see [commit]).
  Future<void> _clearStrayLists() async {
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! File ||
          !entry.path.endsWith('${BackupFormat.extension}$_refs')) {
        continue;
      }
      final main = entry.path.substring(0, entry.path.length - _refs.length);
      if (!await File(main).exists()) await _remove(entry);
    }
  }

  /// A media file leaves only when no kept backup names it. A kept backup
  /// whose list cannot be read stops the pruning: deleting on a guess would
  /// empty a backup that is still the only copy.
  Future<int> _pruneMedia(List<File> kept) async {
    final wanted = <String>{};
    for (final backup in kept) {
      try {
        final text = await File('${backup.path}$_refs').readAsString();
        wanted.addAll(text.split('\n').where((n) => n.isNotEmpty));
      } catch (_) {
        return 0;
      }
    }
    if (!await media.exists()) return 0;
    var removed = 0;
    await for (final entry in media.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!wanted.contains(name) && await _remove(entry)) removed++;
    }
    return removed;
  }

  /// Bytes this account's backup takes on the phone.
  Future<int> size() async {
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }

  Future<void> deleteAll() async {
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {}
  }

  static Future<bool> _remove(File file) async {
    try {
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
