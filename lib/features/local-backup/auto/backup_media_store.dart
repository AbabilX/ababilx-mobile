import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../format/backup_file_writer.dart';
import 'account_backup_dir.dart';

/// Where an attachment's bytes go when they are not written into the backup
/// file itself.
abstract interface class BackupMediaSink {
  /// Marks [fileUrl] as still wanted. True when its bytes are already held,
  /// so the caller need not find the file on the phone at all.
  Future<bool> holds(String fileUrl);

  /// Stores [source] under the `file` [frame]. False when nothing was stored.
  Future<bool> put(Map<String, dynamic> frame, File source);
}

/// Each attachment sealed into its own file, ONCE.
///
/// The automatic backup includes videos and documents, so a backup that
/// copied every file on every run would rewrite gigabytes twice a day and
/// hold them twice. Here a run only writes what is new; the messages file is
/// the only part rewritten.
///
/// A media file is a complete backup file of its own — same header, same
/// sealing, one `file` frame — so a restore reads it with the ordinary reader
/// and no second format exists to keep in step. Its name is a hash of the
/// attachment's URL: nothing in the folder listing says what a file is.
///
/// A file stays while a message that is backed up still refers to it, even
/// after the phone's own copy was cleared (Manage storage, the cache trim).
/// It goes when the message does.
class BackupMediaStore implements BackupMediaSink {
  BackupMediaStore({
    required this.dir,
    required this.accountKey,
    required this.userId,
    required int freeBytes,
    this.reserveBytes = defaultReserveBytes,
  }) : _free = freeBytes;

  /// Free space a run leaves alone. A backup that fills the phone stops the
  /// phone from receiving the next photo.
  static const defaultReserveBytes = 1024 * 1024 * 1024;

  final Directory dir;
  final List<int> accountKey;
  final String userId;
  final int reserveBytes;

  int _free;
  final _wanted = <String>{};
  int _written = 0;
  int _skipped = 0;

  /// Names every included attachment maps to, held or not.
  Set<String> get wanted => _wanted;
  int get written => _written;

  /// Files left out for lack of space. They are tried again on the next run.
  int get skippedForSpace => _skipped;

  static String nameFor(String fileUrl) {
    final hash = sha256.convert(utf8.encode(fileUrl)).toString();
    return '${hash.substring(0, 40)}${AccountBackupDir.mediaExtension}';
  }

  @override
  Future<bool> holds(String fileUrl) async {
    final name = nameFor(fileUrl);
    _wanted.add(name);
    return _whole(File('${dir.path}/$name'));
  }

  /// An empty file is a claim a run never filled (see [put]), not a copy.
  static Future<bool> _whole(File file) async =>
      await file.exists() && await file.length() > 0;

  @override
  Future<bool> put(Map<String, dynamic> frame, File source) async {
    final url = frame['u'];
    if (url is! String || url.isEmpty) return false;
    final name = nameFor(url);
    _wanted.add(name);
    final target = File('${dir.path}/$name');
    final partial = File('${target.path}.partial');
    var claimed = false;
    try {
      final size = await source.length();
      if (_free - size < reserveBytes) {
        _skipped++;
        return false;
      }
      await dir.create(recursive: true);
      if (await _whole(target)) return true;
      if (await target.exists()) await target.delete();
      // Claim the name before sealing a byte. After a reinstall the old copy
      // is still here but hidden from this install, and the name is taken:
      // this fails at once instead of after a whole video was written.
      await target.create(exclusive: true);
      claimed = true;
      final writer = await BackupFileWriter.create(
        partial,
        accountKey: accountKey,
        userId: userId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (!await writer.addFile(frame, source)) {
        await writer.abort();
        await target.delete();
        return false;
      }
      await writer.close();
      await partial.rename(target.path);
      _free -= size;
      _written++;
      return true;
    } catch (_) {
      // A name taken by a copy this install cannot see lands here too; that
      // copy is still on the phone and a restore from the folder reads it.
      try {
        if (await partial.exists()) await partial.delete();
        if (claimed && await target.exists() && await target.length() == 0) {
          await target.delete();
        }
      } catch (_) {}
      return false;
    }
  }
}
