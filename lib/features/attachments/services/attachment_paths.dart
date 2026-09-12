import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models/attachment_url_key.dart';

/// Where the canonical bytes live.
///
/// Application **Support**, not Documents: `ios/Runner/Info.plist` sets both
/// `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, so anything
/// under Documents can be deleted by the user from the Files app. The copy the
/// user is meant to manage is the exported one in the gallery / Downloads;
/// this one must survive.
///
/// Layout: `attachments/<first two key chars>/<key>.<ext>` — the shard keeps
/// any single directory small enough that a listing stays cheap.
class AttachmentPaths {
  AttachmentPaths({Future<Directory> Function()? rootDirectory})
    : _rootDirectory = rootDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _rootDirectory;
  Directory? _root;

  static const dirName = 'attachments';
  static const partSuffix = '.part';

  Future<Directory> root() async {
    final cached = _root;
    if (cached != null) return cached;
    final base = await _rootDirectory();
    final dir = Directory(p.join(base.path, dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  /// Final resting place of a finished download.
  Future<File> fileFor(
    String urlKey,
    String fileName,
    String contentType,
  ) async {
    final dir = await _shard(urlKey);
    final ext = attachmentFileExtension(fileName, contentType);
    return File(p.join(dir.path, '$urlKey.$ext'));
  }

  /// The in-flight file. Sticky across attempts and across app restarts —
  /// its length is what the next request ranges from.
  File partFor(File target) => File('${target.path}$partSuffix');

  Future<Directory> _shard(String urlKey) async {
    final base = await root();
    final shard = urlKey.length >= 2 ? urlKey.substring(0, 2) : '00';
    final dir = Directory(p.join(base.path, shard));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Every `.part` older than [maxAge], for the orphan sweep.
  Future<List<File>> stalePartFiles(Duration maxAge) async {
    final out = <File>[];
    try {
      final base = await root();
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in base.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith(partSuffix)) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) out.add(entity);
      }
    } catch (_) {
      // A sweep that cannot list is a sweep that does nothing.
    }
    return out;
  }

  /// Wipes app-private downloads for account reset or "clear storage".
  Future<void> deleteAll() async {
    final base = await root();
    if (await base.exists()) await base.delete(recursive: true);
    _root = null;
  }
}
