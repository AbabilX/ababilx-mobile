import 'package:flutter/material.dart';

import '../../../shared/widgets/locked_file_placeholder.dart';
import '../data/models/chat_models.dart';
import 'attachment_file_row.dart';
import 'attachment_image_tile.dart';
import 'attachment_pdf_tile.dart';
import 'attachment_video_tile.dart';
import 'voice_attachment_player.dart';

/// Local-first attachment assembly. Transfer progress is watched only by the
/// leaf tiles, so the message row does not rebuild for every downloaded chunk.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({super.key, required this.attachments});

  final List<ChatMessageAttachment> attachments;

  static const _soloMaxHeight = 288.0;
  static const _multiMaxHeight = 160.0;
  static const _multiMaxWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final locked = attachments.where((a) => a.locked).toList();
    final open = attachments.where((a) => !a.locked).toList();
    final images = open.where((a) => a.isImage).toList();
    final videos = open.where((a) => a.isVideo).toList();
    final audio = open.where((a) => a.isAudio).toList();
    final files = open
        .where((a) => !a.isImage && !a.isVideo && !a.isAudio)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.length == 1)
          AttachmentImageTile(
            attachment: images.first,
            gallery: images,
            index: 0,
            maxHeight: _soloMaxHeight,
            maxWidth: double.infinity,
          )
        else if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < images.length; i++)
                AttachmentImageTile(
                  attachment: images[i],
                  gallery: images,
                  index: i,
                  maxHeight: _multiMaxHeight,
                  maxWidth: _multiMaxWidth,
                ),
            ],
          ),
        for (final attachment in videos)
          AttachmentVideoTile(attachment: attachment),
        for (final attachment in audio)
          VoiceAttachmentPlayer(attachment: attachment),
        for (final attachment in files)
          attachment.isPdf
              ? AttachmentPdfTile(attachment: attachment)
              : AttachmentFileRow(attachment: attachment),
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
