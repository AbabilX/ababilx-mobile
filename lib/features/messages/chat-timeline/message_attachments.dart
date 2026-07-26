import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/image_preview.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'chat_file_preview.dart';

/// Web parity: solo max-h-72 (288), multi max-h-40 (160) + contain.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({super.key, required this.attachments});

  final List<ChatMessageAttachment> attachments;

  static const double _soloMaxH = 288;
  static const double _multiMaxH = 160;
  static const double _multiMaxW = 200;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.isImage).toList();
    final audio = attachments.where((a) => a.isAudio).toList();
    final files = attachments.where((a) => !a.isImage && !a.isAudio).toList();
    final colors = Theme.of(context).colorScheme;
    final solo = images.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          solo
              ? _ImageAttachment(
                  attachment: images.first,
                  maxHeight: _soloMaxH,
                  maxWidth: double.infinity,
                  placeholderColor: colors.surfaceContainerHighest,
                  onTap: () => showImagePreview(
                    context,
                    images: [
                      for (final a in images)
                        PreviewImage(fileUrl: a.fileUrl, fileName: a.fileName),
                    ],
                    initialIndex: 0,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < images.length; i++)
                      _ImageAttachment(
                        attachment: images[i],
                        maxHeight: _multiMaxH,
                        maxWidth: _multiMaxW,
                        placeholderColor: colors.surfaceContainerHighest,
                        onTap: () => showImagePreview(
                          context,
                          images: [
                            for (final a in images)
                              PreviewImage(
                                fileUrl: a.fileUrl,
                                fileName: a.fileName,
                              ),
                          ],
                          initialIndex: i,
                        ),
                      ),
                  ],
                ),
        for (final a in audio)
          _VoiceAttachment(
            attachment: a,
            onTap: () => openChatAttachment(context, a),
          ),
        for (final a in files)
          _FileAttachment(
            attachment: a,
            onTap: () => openChatAttachment(context, a),
          ),
      ],
    );
  }
}

class _VoiceAttachment extends StatelessWidget {
  const _VoiceAttachment({required this.attachment, required this.onTap});

  final ChatMessageAttachment attachment;
  final VoidCallback onTap;

  String get _duration {
    final match = RegExp(
      r'voice-message-(\d+)s',
    ).firstMatch(attachment.fileName);
    final seconds = int.tryParse(match?.group(1) ?? '') ?? 0;
    if (seconds == 0) return 'Voice message';
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      10,
                      (index) => Container(
                        width: 2.5,
                        height: 6.0 + ((index * 5) % 15),
                        decoration: BoxDecoration(
                          color: colors.onPrimaryContainer.withValues(
                            alpha: index.isEven ? 0.9 : 0.5,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _duration,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({
    required this.attachment,
    required this.onTap,
    required this.placeholderColor,
    required this.maxHeight,
    required this.maxWidth,
  });

  final ChatMessageAttachment attachment;
  final VoidCallback onTap;
  final Color placeholderColor;
  final double maxHeight;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isSolo = maxWidth == double.infinity;

    return Padding(
      padding: EdgeInsets.only(top: isSolo ? 8 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                maxWidth: maxWidth,
                minHeight: 80,
              ),
              child: CachedNetworkImage(
                imageUrl: attachment.fileUrl,
                width: isSolo ? double.infinity : null,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                placeholder: (_, _) => Container(
                  height: maxHeight * 0.55,
                  width: isSolo ? double.infinity : maxWidth,
                  color: placeholderColor,
                ),
                errorWidget: (_, _, _) => Container(
                  height: 120,
                  width: isSolo ? double.infinity : maxWidth,
                  color: placeholderColor,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment, required this.onTap});

  final ChatMessageAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              ChatIcon(
                attachment.isPdf
                    ? HugeIcons.strokeRoundedPdf02
                    : HugeIcons.strokeRoundedFile01,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.primary, fontSize: 14),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
