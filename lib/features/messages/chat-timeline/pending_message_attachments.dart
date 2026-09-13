import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

class PendingMessageAttachments extends StatelessWidget {
  const PendingMessageAttachments({
    super.key,
    required this.attachments,
    required this.foreground,
    required this.muted,
    required this.uploading,
    this.progress,
  });

  final List<ChatAttachmentInput> attachments;
  final Color foreground;
  final Color muted;
  final bool uploading;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  _iconFor(attachment.contentType),
                  size: 22,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground),
                      ),
                      Text(
                        _formatBytes(attachment.sizeBytes),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (uploading) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: muted.withValues(alpha: .25),
              color: foreground,
            ),
          ),
        ],
      ],
    );
  }
}

IconData _iconFor(String contentType) {
  final type = contentType.toLowerCase();
  if (type.startsWith('image/')) return Icons.image_outlined;
  if (type.startsWith('video/')) return Icons.video_file_outlined;
  if (type.startsWith('audio/')) return Icons.audio_file_outlined;
  if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
  return Icons.insert_drive_file_outlined;
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
