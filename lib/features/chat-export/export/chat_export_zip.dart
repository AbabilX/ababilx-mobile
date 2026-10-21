import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import 'chat_export_staging.dart';

/// Writes [entries] into a zip at [zipPath], off the UI isolate: the zip
/// library is synchronous, and a phone's worth of video would freeze the app.
/// A source that vanished since it was listed is skipped, not fatal.
Future<void> writeChatExportZip(String zipPath, List<ChatExportEntry> entries) {
  final plain = [for (final e in entries) (e.source, e.name, e.store)];
  return Isolate.run(() async {
    final encoder = ZipFileEncoder()..create(zipPath);
    try {
      for (final (source, name, store) in plain) {
        final file = File(source);
        if (!file.existsSync()) continue;
        final input = InputFileStream(source);
        final entry = ArchiveFile.stream(
          name,
          input,
        )..lastModTime = file.lastModifiedSync().millisecondsSinceEpoch ~/ 1000;
        if (store) entry.compression = CompressionType.none;
        encoder.addArchiveFile(entry);
        await input.close();
      }
    } finally {
      await encoder.close();
    }
  });
}
