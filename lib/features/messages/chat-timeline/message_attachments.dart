import 'package:flutter/material.dart';

import '../../../shared/widgets/locked_file_placeholder.dart';
import '../data/models/chat_models.dart';
import 'attachment_file_row.dart';
import 'attachment_image_grid.dart';
import 'attachment_pdf_tile.dart';
import 'attachment_video_tile.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'voice_attachment_player.dart';
import '../../privacy-mode/privacy_timed_card.dart';

/// Local-first attachment assembly. Transfer progress is watched only by the
/// leaf tiles, so the message row does not rebuild for every downloaded chunk.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({
    super.key,
    required this.attachments,
    this.withCaption = false,
    this.captioned = false,
    this.preview,
  });

  final List<ChatMessageAttachment> attachments;

  /// Whether the message also carries body text, which widens a solo picture.
  final bool withCaption;

  /// Text sits under the media (caption bubble). The picture keeps its
  /// edge-to-edge shape but takes Signal's wider floor, since the caption
  /// wraps to the picture's width.
  final bool captioned;

  final ChatMediaPreviewMeta? preview;

  @override
  Widget build(BuildContext context) {
    final locked = attachments.where((a) => a.locked).toList();
    // Privacy mode (server 0152): a timed photo is never drawn inline, and an
    // expired one has nothing left to draw.
    final timed = attachments
        .where((a) => !a.locked && (a.timed || a.expired))
        .toList();
    final open = attachments
        .where((a) => !a.locked && !a.timed && !a.expired)
        .toList();
    final images = open.where((a) => a.isImage).toList();
    final videos = open.where((a) => a.isVideo).toList();
    final audio = open.where((a) => a.isAudio).toList();
    final files = open
        .where((a) => !a.isImage && !a.isVideo && !a.isAudio)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in timed)
          PrivacyTimedCard(attachment: attachment),
        if (images.isNotEmpty)
          AttachmentImageGrid(
            images: images,
            withCaption: withCaption,
            captioned: captioned,
            preview: preview,
          ),
        for (final attachment in videos)
          AttachmentVideoTile(
            attachment: attachment,
            preview: preview,
            inset: withCaption,
            captioned: captioned,
          ),
        for (final attachment in audio)
          VoiceAttachmentPlayer(attachment: attachment),
        for (final attachment in files)
          attachment.isPdf
              ? AttachmentPdfTile(attachment: attachment, preview: preview)
              : AttachmentFileRow(attachment: attachment, preview: preview),
        if (locked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final attachment in locked)
                  LockedFilePlaceholder(fileName: attachment.fileName),
              ],
            ),
          ),
      ],
    );
  }
}
