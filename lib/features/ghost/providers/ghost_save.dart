import 'dart:io';
import 'dart:typed_data';

import '../../../shared/media/save_to_phone.dart';
import 'ghost_state.dart';
import 'ghost_temp_files.dart';

/// Saves a received item the sender allowed to be kept — the one deliberate
/// way Ghost Chat bytes leave the app for good.
///
/// MediaStore copies from a path, so the bytes pass through the ghost temp
/// directory for the length of that copy and are deleted right after (and the
/// directory is purged on the burn and at start regardless).
Future<bool> saveGhostItem(GhostItem item) async {
  final Uint8List? bytes = item.bytes;
  if (!item.rules.allowSave || item.fromMe || bytes == null) return false;
  final name = item.fileName ?? 'ghost';
  String? path;
  try {
    path = await GhostTempFiles.writeForOpen(name, bytes);
    final result = await saveFileToPhone(
      SaveToPhoneRequest(
        sourcePath: path,
        fileName: name,
        contentType: item.mime ?? '',
      ),
    );
    return result.ok;
  } catch (_) {
    return false;
  } finally {
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {
        // Purged on the burn and at the next start.
      }
    }
  }
}
