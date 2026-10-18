import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../format/backup_file_writer.dart';
import 'account_backup_dir.dart';
import 'backup_folder_view.dart';

/// The automatic backup's messages, sealed one week at a time and written
/// ONCE — the media store's rule, applied to text.
///
/// Every run used to decrypt and re-seal the whole history into a new file,
/// so "Back up now" counted from the first message again however little had
/// changed. Now a week is named by a hash of what it holds: a week nothing
/// touched keeps its name and its file, and a run only writes the weeks that
/// are new or changed (a message sent, edited, reacted to, deleted, or an
/// older page fetched from the server since). The weeks a backup uses are
/// listed in its main file (`seg` frames), newest first.
///
/// A week is an ordinary backup file of `msg` frames beside the media, with
/// the media extension, so every restore that reads the media folder — this
/// build's and the ones before it — imports it with the ordinary reader. The
/// name says it holds messages (`m` prefix) and nothing about when or whose.
class BackupMessageSegments {
  BackupMessageSegments({
    required this.dir,
    required this.accountKey,
    required this.userId,
    this.installTag = '',
    this.folderView,
  });

  static const _weekMs = 7 * 24 * 60 * 60 * 1000;
  static const _prefix = 'm';

  final Directory dir;
  final List<int> accountKey;
  final String userId;

  /// See [BackupFolderView]: a week an earlier install sealed is not ours.
  final String installTag;

  /// Given by tests; otherwise listed from [dir] on first use.
  final BackupFolderView? folderView;
  BackupFolderView? _view;

  Future<BackupFolderView> _folder() async => _view ??=
      folderView ?? await BackupFolderView.read(dir, installTag: installTag);

  /// Names every week of this run maps to, written or kept.
  final wanted = <String>{};
  int written = 0;
  int reused = 0;

  static int weekOf(int timeMs) => timeMs ~/ _weekMs;

  /// Whether a media-folder name is a message week rather than a file.
  static bool isSegmentName(String name) =>
      name.startsWith(_prefix) &&
      name.endsWith(AccountBackupDir.mediaExtension);

  String nameFor(int week, String contentHash) {
    final digest = sha256
        .convert(utf8.encode('abx-msgs-v1:$userId:$week:$contentHash'))
        .toString();
    return '$_prefix${digest.substring(0, 39)}'
        '${AccountBackupDir.mediaExtension}';
  }

  /// The name this exact week is already sealed under here (kept), or null.
  /// It may be this install's alternative to [name].
  Future<String?> keep(String name) async {
    final held = (await _folder()).held(name);
    if (held == null) return null;
    wanted.add(held);
    reused++;
    return held;
  }

  /// A writer for a new week. [commit] names it once its content is known.
  Future<(BackupFileWriter, File)> open() async {
    await dir.create(recursive: true);
    final partial = File(
      '${dir.path}/${_prefix}week-${DateTime.now().microsecondsSinceEpoch}'
      '.partial',
    );
    final writer = await BackupFileWriter.create(
      partial,
      accountKey: accountKey,
      userId: userId,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return (writer, partial);
  }

  /// Gives the sealed [partial] its content name. If that week is already
  /// here (the store moved back to what an earlier run sealed), that copy is
  /// kept and this one dropped.
  ///
  /// Returns the name it went under. Throws when strangers hold both of its
  /// names, which takes two installs with this install's own tag — never.
  Future<String> commit(File partial, String name) async {
    final folder = await _folder();
    final held = folder.held(name);
    if (held != null) {
      await partial.delete();
      reused++;
      wanted.add(held);
      return held;
    }
    final free = await folder.free(name);
    if (free == null) {
      await partial.delete();
      throw FileSystemException('week name taken', '${dir.path}/$name');
    }
    final target = File('${dir.path}/$free');
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    folder.wrote(free, await target.length());
    written++;
    wanted.add(free);
    return free;
  }
}

/// One week as the scan pass saw it: where it starts in the store's export
/// order, how many rows it holds, and their hash.
class BackupWeekScan {
  BackupWeekScan(this.week, {required this.afterMs, required this.afterId});

  final int week;

  /// The store cursor just before this week's first message.
  final int? afterMs;
  final String? afterId;
  final hash = BackupWeekHasher();
  int count = 0;

  void add(String storedJson) {
    hash.add(storedJson);
    count++;
  }
}

/// A week's rows, hashed the same way by the scan pass and the write pass.
class BackupWeekHasher {
  BackupWeekHasher() {
    _input = sha256.startChunkedConversion(_sink);
  }

  final _sink = _DigestSink();
  late final ByteConversionSink _input;

  void add(String storedJson) {
    _input
      ..add(utf8.encode(storedJson))
      ..add(const [0x0A]);
  }

  /// The hash of everything added. Call once.
  String close() {
    _input.close();
    return _sink.value.toString();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}
