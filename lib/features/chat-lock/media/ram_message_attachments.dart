import 'package:flutter/material.dart';

import '../../../shared/widgets/locked_file_placeholder.dart';
import '../../../shared/widgets/voice_url_player.dart';
import '../../messages/chat-timeline/bubble_metrics.dart';
import '../../messages/data/models/chat_models.dart';
import '../../privacy-mode/privacy_timed_card.dart';
import 'ram_file_row.dart';
import 'ram_media_cache.dart';
import 'ram_photo_tile.dart';
import 'ram_photo_viewer.dart';
import 'ram_sealed_media.dart';

/// A locked chat's attachments, drawn without the attachment store: photos
/// from memory, voice notes and videos streamed from their URL, files opened
/// from memory. The ordinary `MessageAttachments` downloads everything to
/// disk first, which is exactly what a locked chat must not do.
///
/// Plainer than the ordinary layout on purpose — no measured frame lock and
/// no poster frames, since measuring and poster extraction both work on a
/// file.
class RamMessageAttachments extends StatelessWidget {
  const RamMessageAttachments({super.key, required this.attachments});

  final List<ChatMessageAttachment> attachments;

  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    // Encrypted files (server 0168) are opened in memory by the cache.
    RamMediaCache.know(attachments);
    final retained = attachments.where((a) => a.locked).toList();
    final timed = attachments
        .where((a) => !a.locked && (a.timed || a.expired))
        .toList();
    final open = attachments
        .where(
          (a) => !a.locked && !a.timed && !a.expired && a.fileUrl.isNotEmpty,
        )
        .toList();
    // An encrypted file whose key did not open here is a plain row that
    // says so on tap — never a tile trying to draw ciphertext.
    final photos = open.where((a) => a.isImage && !a.needsKey).toList();
    final audio = open
        .where((a) => a.isAudio && !a.isVideo && !a.needsKey)
        .toList();
    final files = open
        .where((a) => !photos.contains(a) && !audio.contains(a))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in timed) PrivacyTimedCard(attachment: a),
        if (photos.isNotEmpty) _photos(context, photos),
        for (final a in audio)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: a.secret != null
                ? RamSealedVoice(attachment: a)
                : VoiceUrlPlayer(
                    source: AudioSourceRef.url(a.fileUrl),
                    fileName: a.fileName,
                  ),
          ),
        for (final a in files) RamFileRow(attachment: a),
        if (retained.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in retained)
                  LockedFilePlaceholder(fileName: a.fileName),
              ],
            ),
          ),
      ],
    );
  }

  Widget _photos(BuildContext context, List<ChatMessageAttachment> photos) {
    final urls = [for (final p in photos) p.fileUrl];
    void open(int i) => showRamPhotos(context, urls: urls, initial: i);
    if (photos.length == 1) {
      const side = BubbleMetrics.mediaDefaultSize;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: RamPhotoTile(
          url: urls.first,
          size: const Size.square(side),
          onTap: () => open(0),
        ),
      );
    }
    const cell = (BubbleMetrics.mediaMaxWidth - _gap) / 2;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: BubbleMetrics.mediaMaxWidth,
        child: Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var i = 0; i < urls.length; i++)
              RamPhotoTile(
                url: urls[i],
                size: const Size.square(cell),
                radius: 6,
                onTap: () => open(i),
              ),
          ],
        ),
      ),
    );
  }
}
