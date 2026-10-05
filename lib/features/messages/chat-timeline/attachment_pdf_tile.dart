import 'package:flutter/material.dart';

import '../../../shared/widgets/pdf_preview.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'media-preview/chat_media_preview_meta.dart';

class AttachmentPdfTile extends StatelessWidget {
  const AttachmentPdfTile({
    super.key,
    required this.attachment,
    this.preview,
    this.bleed = false,
  });

  final ChatMessageAttachment attachment;
  final ChatMediaPreviewMeta? preview;

  /// Edge to edge in the bubble: no top margin, square corners.
  final bool bleed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: bleed ? 0 : 6),
      child: AttachmentGate(
        attachment: attachment,
        reserveSpace: true,
        height: 200,
        ready: (_, handle) => PdfPreviewCard(
          source: PdfDocumentSource.file(handle.localPath!),
          fileName: attachment.fileName,
          height: 200,
          flat: bleed,
          detail: preview?.detail,
          caption: preview?.caption,
        ),
      ),
    );
  }
}
