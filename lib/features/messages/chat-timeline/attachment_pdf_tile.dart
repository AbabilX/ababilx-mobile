import 'package:flutter/material.dart';

import '../../../shared/widgets/pdf_preview.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'media-preview/chat_media_preview_meta.dart';

class AttachmentPdfTile extends StatelessWidget {
  const AttachmentPdfTile({super.key, required this.attachment, this.preview});

  final ChatMessageAttachment attachment;
  final ChatMediaPreviewMeta? preview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AttachmentGate(
        attachment: attachment,
        reserveSpace: true,
        height: 200,
        ready: (_, handle) => PdfPreviewCard(
          source: PdfDocumentSource.file(handle.localPath!),
          fileName: attachment.fileName,
          height: 200,
          detail: preview?.detail,
          caption: preview?.caption,
        ),
      ),
    );
  }
}
