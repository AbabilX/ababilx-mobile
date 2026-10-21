import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../format/chat_export_format.dart';
import '../format/chat_export_manifest.dart';

/// Why an import was refused; each is a translation key.
class ChatImportFailure implements Exception {
  const ChatImportFailure(this.messageKey);
  final String messageKey;

  static const notExport = ChatImportFailure('chat_import_error_not_export');
  static const unreadable = ChatImportFailure('chat_import_error_unreadable');
}

/// The only paths an export holds. Anything else in the zip is ignored —
/// a zip can come from anyone, so nothing it names may land outside its
/// folder or overwrite another file's place.
final _allowed = RegExp(
  r'^chats/[^/\\]+/(messages\.txt|messages\.json|media/[^/\\]+)$',
);

bool chatImportPathAllowed(String name, Set<String> folders) {
  if (name == ChatExportFormat.manifest || name == ChatExportFormat.readme) {
    return true;
  }
  if (!_allowed.hasMatch(name)) return false;
  if (name.split('/').any((s) => s == '..' || s == '.' || s.isEmpty)) {
    return false;
  }
  return folders.contains(name.split('/')[1]);
}

/// Unpacks [zipPath] into [outDir] off the UI isolate; returns the manifest.
/// Throws [ChatImportFailure] when it is not an AbabilX chat export.
Future<ChatExportManifest> unzipChatExport(
  String zipPath,
  String outDir,
) async {
  final String? raw;
  try {
    raw = await Isolate.run(() => _unzip(zipPath, outDir));
  } catch (_) {
    throw ChatImportFailure.unreadable;
  }
  if (raw == null) throw ChatImportFailure.notExport;
  return ChatExportManifest.tryParse(jsonDecode(raw))!;
}

/// The manifest's JSON text, or null when this is not an export. A failure
/// while writing (no space left) throws.
Future<String?> _unzip(String zipPath, String outDir) async {
  final input = InputFileStream(zipPath);
  try {
    final Archive archive;
    final String text;
    final ChatExportManifest? manifest;
    try {
      archive = ZipDecoder().decodeStream(input);
      final head = archive.findFile(ChatExportFormat.manifest);
      if (head == null) return null;
      text = utf8.decode(head.content, allowMalformed: true);
      manifest = ChatExportManifest.tryParse(jsonDecode(text));
    } catch (_) {
      return null;
    }
    if (manifest == null) return null;
    final folders = {
      for (final c in manifest.chats)
        if (c.folder.isNotEmpty && !c.folder.contains('/')) c.folder,
    };
    final root = p.canonicalize(outDir);
    for (final file in archive.files) {
      if (!file.isFile || !chatImportPathAllowed(file.name, folders)) continue;
      final dest = p.canonicalize(p.join(root, file.name));
      if (!p.isWithin(root, dest)) continue;
      await Directory(p.dirname(dest)).create(recursive: true);
      final out = OutputFileStream(dest);
      file.writeContent(out);
      await out.close();
    }
    return text;
  } finally {
    await input.close();
  }
}
