import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../attachments/widgets/attachment_gate.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'chat_file_preview.dart';

class AttachmentFileRow extends StatelessWidget {
  const AttachmentFileRow({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AttachmentGate(
        attachment: attachment,
        height: 56,
        showSize: true,
        ready: (_, handle) => _content(context, handle.localPath!),
      ),
    );
  }

  Widget _content(BuildContext context, String localPath) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () =>
          openChatAttachment(context, attachment, localPath: localPath),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedFile01,
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
    );
  }
}
