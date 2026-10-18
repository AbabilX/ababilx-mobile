import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The automatic folder's `media/` as THIS install sees it.
///
/// After a reinstall the old install's files are still in the folder, and
/// Android lets the new install find one by name (`exists` says yes) but not
/// list it or read it. Trusting `exists` counted every such photo as backed
/// up on every run, while this install's own restore — which reads what it
/// can list — brought back none of them (device, 2026-10-18: 359 held, 0
/// restored).
///
/// So a file counts only when this install listed it. A name a stranger's
/// file already holds is written under this install's alternative instead:
/// [installTag] makes that alternative unique per install, so a second or a
/// fifth reinstall never runs out of names. Restore reads the names the
/// backup recorded, so the alternative needs no lookup of its own.
class BackupFolderView {
  BackupFolderView(
    this.dir,
    Map<String, int> own, {
    required this.installTag,
    Future<bool> Function(String path)? exists,
  }) : _own = own,
       _exists = exists ?? ((path) => File(path).exists());

  static Future<BackupFolderView> read(
    Directory dir, {
    required String installTag,
  }) async {
    final own = <String, int>{};
    if (await dir.exists()) {
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) continue;
        try {
          own[entry.uri.pathSegments.last] = (await entry.stat()).size;
        } catch (_) {}
      }
    }
    return BackupFolderView(dir, own, installTag: installTag);
  }

  final Directory dir;
  final String installTag;
  final Map<String, int> _own;
  final Future<bool> Function(String path) _exists;

  /// [base], then this install's alternative to it — same shape, so the
  /// folder listing still says nothing about what a file is.
  List<String> candidates(String base) {
    final dot = base.lastIndexOf('.');
    final stem = dot < 0 ? base : base.substring(0, dot);
    final ext = dot < 0 ? '' : base.substring(dot);
    // A hex digest never starts with a letter past f: `m` marks a week.
    final prefix = stem.startsWith('m') ? 'm' : '';
    final digest = sha256
        .convert(utf8.encode('abx-alt-v1:$stem:$installTag'))
        .toString();
    final length = (stem.length - prefix.length).clamp(1, digest.length);
    return [base, '$prefix${digest.substring(0, length)}$ext'];
  }

  /// The candidate this install holds whole, or null.
  String? held(String base) {
    for (final name in candidates(base)) {
      if ((_own[name] ?? 0) > 0) return name;
    }
    return null;
  }

  /// Where [base]'s content may be written: a candidate that is free, or an
  /// empty one this install left behind. Null when strangers hold both.
  Future<String?> free(String base) async {
    for (final name in candidates(base)) {
      final size = _own[name];
      if (size != null) return name;
      if (!await _exists('${dir.path}/$name')) return name;
    }
    return null;
  }

  /// Records a file this run wrote whole.
  void wrote(String name, int size) => _own[name] = size;
}
