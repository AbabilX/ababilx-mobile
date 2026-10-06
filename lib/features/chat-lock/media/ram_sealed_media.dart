import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/video_fullscreen_dialog.dart';
import '../../../shared/widgets/video_source.dart';
import '../../../shared/widgets/voice_url_player.dart';
import '../../ghost/native/ghost_blobs.dart';
import '../../messages/data/models/chat_models.dart';
import 'ram_media_cache.dart';

/// A locked chat's encrypted video and voice notes (server 0168).
///
/// Their plaintext siblings stream straight from the URL, which is how a
/// locked chat keeps them off the disk. An encrypted object cannot be
/// streamed — what is at the URL is ciphertext — so these are fetched into
/// memory, opened there ([RamMediaCache]), and played from memory. Still
/// nothing is written to a file.

/// Plays an encrypted video from memory. False when it could not be played —
/// too large to hold, or no memory-backed player on this platform — so the
/// caller can say so.
Future<bool> playRamSealedVideo(
  BuildContext context,
  ChatMessageAttachment attachment,
) async {
  if (attachment.sizeBytes > RamMediaCache.maxFileBytes) return false;
  final bytes = await RamMediaCache.fetch(attachment.fileUrl);
  final uri = await GhostBlobs.put(
    attachment.fileName,
    attachment.contentType.isEmpty ? 'video/mp4' : attachment.contentType,
    bytes,
    key: RamMediaCache.blobKey(attachment.fileUrl),
  );
  if (uri == null || !context.mounted) return false;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      // The empty name keeps Save and Share off, as for a streamed one.
      builder: (_) => FullscreenVideoDialog(source: VideoSource.content(uri)),
    ),
  );
  return true;
}

/// An encrypted voice note: the player appears once the bytes are in memory.
class RamSealedVoice extends StatefulWidget {
  const RamSealedVoice({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  State<RamSealedVoice> createState() => _RamSealedVoiceState();
}

class _RamSealedVoiceState extends State<RamSealedVoice> {
  late Future<Uint8List> _bytes = RamMediaCache.fetch(
    widget.attachment.fileUrl,
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return VoiceUrlPlayer(
            source: AudioSourceRef(
              id: a.fileUrl,
              source: BytesSource(
                bytes,
                mimeType: a.contentType.isEmpty ? null : a.contentType,
              ),
            ),
            fileName: a.fileName,
            waveSeed: a.fileUrl,
          );
        }
        if (snapshot.hasError) {
          return IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                setState(() => _bytes = RamMediaCache.fetch(a.fileUrl)),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(10),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
