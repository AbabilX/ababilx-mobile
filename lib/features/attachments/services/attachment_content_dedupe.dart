import 'dart:io';

import '../data/local/attachment_dedupe_store.dart';

/// The path this download's row should commit to, and — only once that
/// commit has landed — the file, if any, that is now redundant and safe to
/// remove.
///
/// Deliberately does not delete anything itself. `redundantFile` still
/// exists on disk and belongs to nobody's committed row until the caller
/// writes [path] to the database; deleting it before that write lands would
/// leave a crash-in-between with no evidence the delete ever happened. See
/// [AttachmentSweeper] for the other half — reclaiming a `redundantFile`
/// that a crash prevented the caller from deleting.
class DedupeResolution {
  const DedupeResolution({required this.path, this.redundantFile});

  final String path;
  final File? redundantFile;
}

/// Where a finished download's bytes should actually live.
///
/// If this device already holds these exact bytes under a different
/// `urlKey` (the same photo sent by two people, or re-uploaded), the existing
/// copy wins and the one just downloaded becomes `redundantFile`. Falls back
/// to the fresh download if the existing copy turns out to be gone —
/// eviction and re-download can both race this — or if it turns out to *be*
/// the fresh download (a re-download landing on a path another row already
/// deduped onto must not treat its own file as redundant).
Future<DedupeResolution> resolveDedupedStoragePath(
  AttachmentDedupeStore dedupe,
  String urlKey,
  String contentHash,
  File downloaded,
) async {
  final duplicate = await dedupe.findReadyByContentHash(
    contentHash,
    excludingUrlKey: urlKey,
  );
  final existingPath = duplicate?.localPath ?? '';
  if (existingPath.isEmpty ||
      existingPath == downloaded.path ||
      !await File(existingPath).exists()) {
    return DedupeResolution(path: downloaded.path);
  }
  return DedupeResolution(path: existingPath, redundantFile: downloaded);
}
