import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/widgets/attachment_download_badge.dart';
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
        reserveSpace: true,
        height: 56,
        showSize: false,
        waiting: (_, handle) => _content(context, handle: handle),
        ready: (_, handle) =>
            _content(context, handle: handle, localPath: handle.localPath),
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required AttachmentHandle? handle,
    String? localPath,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isReady = localPath != null && localPath.isNotEmpty;
    return InkWell(
      onTap: isReady
          ? () => openChatAttachment(context, attachment, localPath: localPath)
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
            const SizedBox(width: 8),
            if (isReady)
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              )
            else if (handle != null)
              AttachmentDownloadBadge(
                attachment: attachment,
                handle: handle,
                showSize: false,
              )
            else
              const SizedBox.square(dimension: 44),
          ],
        ),
      ),
    );
  }
}
