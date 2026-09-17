import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/media/picked_media_file.dart'
    show contentTypeForFileName;
import '../protocol/ghost_frames.dart';
import '../providers/ghost_temp_files.dart';

/// A file chosen for a Ghost Chat, already out of the picker's cache.
class GhostPicked {
  const GhostPicked(this.name, this.mime, this.bytes);
  final String name;
  final String mime;
  final Uint8List bytes;
}

enum GhostPickSource { gallery, camera, file }

/// Picks one file and reads it into memory.
///
/// Both picker plugins copy the chosen file into this app's cache before
/// handing over a path, and nothing ever cleans that copy up. The chat's
/// ordinary composer can live with that; a Ghost Chat cannot, so the copy is
/// deleted the moment its bytes are read. The user's own original is never
/// touched — only a path inside our cache directory is ever removed.
///
/// Throws [GhostFileTooLarge] before reading a file over the limit.
Future<GhostPicked?> pickForGhost(GhostPickSource source) async {
  switch (source) {
    case GhostPickSource.gallery:
    case GhostPickSource.camera:
      final file = source == GhostPickSource.camera
          ? await ImagePicker().pickImage(
              source: ImageSource.camera,
              imageQuality: 88,
              maxWidth: 2400,
            )
          : await ImagePicker().pickMedia();
      if (file == null) return null;
      try {
        if (await file.length() > maxGhostFileBytes) throw GhostFileTooLarge();
        final bytes = await file.readAsBytes();
        return GhostPicked(
          file.name,
          file.mimeType ?? contentTypeForFileName(file.name),
          bytes,
        );
      } finally {
        await GhostTempFiles.deletePickerCopy(file.path);
      }
    case GhostPickSource.file:
      final result = await FilePicker.platform.pickFiles(withData: false);
      final file = result?.files.firstOrNull;
      if (file == null) return null;
      try {
        if (file.size > maxGhostFileBytes) throw GhostFileTooLarge();
        final path = file.path;
        if (path == null) return null;
        final bytes = await XFile(path).readAsBytes();
        return GhostPicked(file.name, contentTypeForFileName(file.name), bytes);
      } finally {
        await GhostTempFiles.deletePickerCopy(file.path);
      }
  }
}

class GhostFileTooLarge implements Exception {}
