import 'package:flutter/material.dart';

import '../../../shared/widgets/pdf_preview.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';

class AttachmentPdfTile extends StatelessWidget {
  const AttachmentPdfTile({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AttachmentGate(
        attachment: attachment,
        height: 200,
        ready: (_, handle) => PdfPreviewCard(
          source: PdfDocumentSource.file(handle.localPath!),
          fileName: attachment.fileName,
          height: 200,
        ),
      ),
    );
  }
}
