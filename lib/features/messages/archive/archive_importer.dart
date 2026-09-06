import 'dart:convert';
import 'dart:typed_data';

import '../data/local/chat_message_store.dart';
import '../data/models/chat_models.dart';
import 'archive_api.dart';
import 'archive_frames.dart';
import 'archive_key.dart';
import 'archive_reader.dart';

/// Restores a sealed archive into the device's local store.
///
/// **Merge, never wipe.** Rows are written by server id, so replaying an
/// archive over a store that already holds some of it converges instead of
/// duplicating — and a restore that is interrupted can simply be run again.
/// Signal's import wipes first because it restores a whole database including
/// its own identity; ours restores message rows into a store the app is
/// already using, and there is no transaction spanning the platform channel to
/// make a wipe safe.
class ArchiveImporter {
  ArchiveImporter({
    required this.store,
    required this.api,
    required this.identityScalar,
    this.onProgress,
  });

  final ChatMessageStore store;
  final ArchiveApi api;
  final List<int> identityScalar;
  final void Function(int restored)? onProgress;

  /// How many messages are buffered before a write. Large enough that a
  /// restore is not one round trip per row, small enough that a failure loses
  /// little.
  static const _batch = 200;

  Future<ArchiveImportResult> run(ArchiveManifest manifest) async {
    final salt = base64Url.decode(base64Url.normalize(manifest.salt));
    final key = await ArchiveKey.derive(identityScalar, salt);

    var restored = 0;
    final pending = <ChatMessage>[];
    Future<void> flush() async {
      if (pending.isEmpty) return;
      await store.saveAll(List<ChatMessage>.from(pending));
      restored += pending.length;
      pending.clear();
      onProgress?.call(restored);
    }

    final reader = ArchiveReader(
      key: key,
      onFrame: (frame) async {
        final message = frame.type == ArchiveFrame.message
            ? frame.asMessage()
            : null;
        if (message == null) return;
        pending.add(message);
        if (pending.length >= _batch) await flush();
      },
    );

    for (final url in manifest.chunks) {
      final bytes = await api.getChunk(url);
      if (bytes.length <= 12) {
        throw const ArchiveTruncatedError('archive chunk is empty');
      }
      await reader.addChunk(
        ArchiveChunk(
          nonce: Uint8List.fromList(bytes.sublist(0, 12)),
          ciphertext: Uint8List.fromList(bytes.sublist(12)),
        ),
      );
    }
    // finish() throws if the terminator is missing, so a partially uploaded
    // archive fails here rather than restoring a plausible short history.
    await reader.finish();
    await flush();
    return ArchiveImportResult(
      restored: restored,
      skipped: reader.framesSkipped,
      generation: manifest.generation,
    );
  }
}

class ArchiveImportResult {
  const ArchiveImportResult({
    required this.restored,
    required this.skipped,
    required this.generation,
  });

  final int restored;
  final int skipped;
  final int generation;
}
