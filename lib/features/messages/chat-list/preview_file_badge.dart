import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

/// Glyph for an attachment in a chat-list preview.
IconData previewFileIcon(ChatLastAttachment file) {
  if (file.isImage) return Icons.image_outlined;
  if (file.isVideo) return Icons.videocam_outlined;
  if (file.isAudio) return Icons.graphic_eq_rounded;
  if (file.isPdf) return Icons.picture_as_pdf_outlined;
  return Icons.attach_file_rounded;
}

/// What an attachment is called in the list. Photos and videos say their kind,
/// as Signal's list does: a camera file name ("Photo on 18-7-2…") tells the
/// reader nothing. Documents keep their name, which is the useful part.
String previewFileLabel(ChatLastAttachment file) {
  if (file.isImage) return 'Photo';
  if (file.isVideo) return 'Video';
  if (file.isAudio) return 'Audio';
  final name = file.fileName.trim();
  if (name.isNotEmpty) return name;
  return file.isPdf ? 'PDF' : 'File';
}

/// Attachment-only message: one line, `[You: ] (icon) Photo +2`.
List<InlineSpan> attachmentOnlySpans({
  required List<ChatLastAttachment> files,
  required TextStyle style,
  required ColorScheme colors,
}) {
  final first = files.first;
  final more = files.length - 1;
  return [
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          previewFileIcon(first),
          size: (style.fontSize ?? 14) + 2,
          color: style.color ?? colors.onSurfaceVariant,
        ),
      ),
    ),
    TextSpan(
      text: more > 0
          ? '${previewFileLabel(first)} +$more'
          : previewFileLabel(first),
      style: style,
    ),
  ];
}

class PreviewFileBadge extends StatelessWidget {
  const PreviewFileBadge({super.key, required this.file, required this.colors});

  final ChatLastAttachment file;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(previewFileIcon(file), size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              previewFileLabel(file),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
