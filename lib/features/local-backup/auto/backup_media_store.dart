import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../format/backup_file_writer.dart';
import 'account_backup_dir.dart';
import 'backup_folder_view.dart';

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
    this.installTag = '',
    this.folderView,
  }) : _free = freeBytes;

  /// Free space a run leaves alone. A backup that fills the phone stops the
  /// phone from receiving the next photo.
  static const defaultReserveBytes = 1024 * 1024 * 1024;

  final Directory dir;
  final List<int> accountKey;
  final String userId;
  final int reserveBytes;

  /// See [BackupFolderView]: whose files this install may count as its own.
  final String installTag;

  /// Given by tests; otherwise listed from [dir] on first use.
  final BackupFolderView? folderView;
  BackupFolderView? _view;

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

  /// Read once per run: one listing instead of two calls per attachment.
  Future<BackupFolderView> _folder() async => _view ??=
      folderView ?? await BackupFolderView.read(dir, installTag: installTag);

  @override
  Future<bool> holds(String fileUrl) async {
    final base = nameFor(fileUrl);
    final held = (await _folder()).held(base);
    // Not held, nothing to keep: a stranger's file is not ours to name.
    if (held != null) _wanted.add(held);
    return held != null;
  }

  @override
  Future<bool> put(Map<String, dynamic> frame, File source) async {
    final url = frame['u'];
    if (url is! String || url.isEmpty) return false;
    final base = nameFor(url);
    final folder = await _folder();
    final held = folder.held(base);
    if (held != null) {
      _wanted.add(held);
      return true;
    }
    // A name a stranger's file holds (an earlier install) gets this
    // install's alternative; both taken is a file this run cannot store.
    final name = await folder.free(base);
    if (name == null) return false;
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
      if (await target.exists()) await target.delete();
      // Claim the name before sealing a byte, so a name taken after the
      // listing fails at once instead of after a whole video was written.
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
      folder.wrote(name, await target.length());
      _free -= size;
      _written++;
      return true;
    } catch (_) {
      // Tried again next run: nothing here is counted as stored.
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
