import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../profile/providers/profile_provider.dart';
import '../format/chat_export_format.dart';
import '../format/chat_export_manifest.dart';
import 'chat_import_unzip.dart';

/// One imported zip, unpacked on this phone.
class ImportedArchive {
  const ImportedArchive(this.id, this.dir, this.manifest);

  final String id;
  final Directory dir;
  final ChatExportManifest manifest;

  ExportedChat? chat(String folder) {
    for (final c in manifest.chats) {
      if (c.folder == folder) return c;
    }
    return null;
  }

  Directory chatDir(String folder) =>
      Directory('${dir.path}/${ChatExportFormat.chatsDir}/$folder');
}

/// Imported chat exports, per signed-in account (user's call, 2026-10-21: a
/// zip from ANY account can be imported). They are a read-only archive on
/// this phone: nothing is sent to the server or to anyone, and the live
/// chats are never touched.
class ChatImportStore {
  ChatImportStore(this.userId);

  final String userId;

  Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/chat_imports/$userId');
  }

  Future<ImportedArchive> import(String zipPath) async {
    final root = await _root();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final partial = Directory('${root.path}/$id.partial');
    await partial.create(recursive: true);
    try {
      final manifest = await unzipChatExport(zipPath, partial.path);
      final done = await partial.rename('${root.path}/$id');
      return ImportedArchive(id, done, manifest);
    } catch (_) {
      try {
        await partial.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  /// Newest import first. Half-written imports (`.partial`) are cleared.
  Future<List<ImportedArchive>> list() async {
    final root = await _root();
    if (!await root.exists()) return const [];
    final out = <ImportedArchive>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (id.endsWith('.partial')) {
        await entry.delete(recursive: true).catchError((_) => entry);
        continue;
      }
      try {
        final file = File('${entry.path}/${ChatExportFormat.manifest}');
        final manifest = ChatExportManifest.tryParse(
          jsonDecode(await file.readAsString()),
        );
        if (manifest != null) out.add(ImportedArchive(id, entry, manifest));
      } catch (_) {}
    }
    out.sort((a, b) => b.id.compareTo(a.id));
    return out;
  }

  Future<void> delete(ImportedArchive archive) async {
    if (await archive.dir.exists()) await archive.dir.delete(recursive: true);
  }

  /// A chat's messages, oldest first, parsed off the UI isolate.
  static Future<List<ExportedMessage>> messages(Directory chatDir) {
    final path = '${chatDir.path}/${ChatExportFormat.messagesJson}';
    return Isolate.run(() {
      final json = jsonDecode(File(path).readAsStringSync());
      final list = json is Map ? json['messages'] : null;
      return [
        for (final m in list is List ? list : const [])
          if (m is Map) ExportedMessage.fromJson(Map<String, dynamic>.from(m)),
      ];
    });
  }
}

final chatImportStoreProvider = Provider<ChatImportStore>((ref) {
  final id = ref.watch(profileProvider.select((p) => p.valueOrNull?.id));
  return ChatImportStore(id ?? '');
});

final importedArchivesProvider =
    FutureProvider.autoDispose<List<ImportedArchive>>((ref) {
      final store = ref.watch(chatImportStoreProvider);
      if (store.userId.isEmpty) return const [];
      return store.list();
    });
