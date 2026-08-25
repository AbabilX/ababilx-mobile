import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/image_preview.dart';
import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';

class AttachmentImageTile extends ConsumerWidget {
  const AttachmentImageTile({
    super.key,
    required this.attachment,
    required this.gallery,
    required this.index,
    required this.maxHeight,
    required this.maxWidth,
  });

  final ChatMessageAttachment attachment;
  final List<ChatMessageAttachment> gallery;
  final int index;
  final double maxHeight;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solo = maxWidth == double.infinity;
    return Padding(
      padding: EdgeInsets.only(top: solo ? 8 : 0),
      child: AttachmentGate(
        attachment: attachment,
        height: solo ? maxHeight * 0.55 : maxHeight,
        width: solo ? null : maxWidth,
        ready: (context, handle) => _ready(context, ref, handle, solo),
      ),
    );
  }

  Widget _ready(
    BuildContext context,
    WidgetRef ref,
    AttachmentHandle handle,
    bool solo,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context, ref),
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: maxWidth,
              minHeight: 80,
            ),
            child: Image.file(
              handle.file!,
              width: solo ? double.infinity : null,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, _, _) => _broken(context, solo),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final handles = await ref
        .read(attachmentAuthorityProvider)
        .resolveAll(gallery);
    if (!context.mounted) return;
    await showImagePreview(
      context,
      images: [
        for (var i = 0; i < gallery.length; i++)
          PreviewImage(
            fileUrl: gallery[i].fileUrl,
            fileName: gallery[i].fileName,
            localPath: handles[i].isReady ? handles[i].localPath : null,
          ),
      ],
      initialIndex: index,
      allowRemoteFallback: false,
    );
  }

  Widget _broken(BuildContext context, bool solo) => Container(
    height: 120,
    width: solo ? double.infinity : maxWidth,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}
