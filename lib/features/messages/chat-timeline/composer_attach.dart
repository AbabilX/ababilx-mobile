import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

class ComposerPendingChips extends StatelessWidget {
  const ComposerPendingChips({
    super.key,
    required this.items,
    required this.onRemove,
  });

  final List<ChatAttachmentInput> items;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Chip(
          label: Text(items[i].fileName, overflow: TextOverflow.ellipsis),
          onDeleted: () => onRemove(i),
        ),
      ),
    );
  }
}

Future<void> pickAndUploadImage(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedImage01),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedCamera01),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;
  final file = await ImagePicker().pickImage(source: source);
  if (file == null) return;
  final bytes = await file.readAsBytes();
  final contentType = file.mimeType ?? 'image/jpeg';
  final n = ref.read(chatProvider.notifier);
  final presign = await n.presignAttachment(
    conversationId,
    contentType: contentType,
    fileName: file.name,
    sizeBytes: bytes.length,
  );
  await n.uploadAttachmentBytes(presign, bytes, contentType);
  onAdded(
    ChatAttachmentInput(
      fileUrl: presign.publicUrl,
      fileName: file.name,
      contentType: contentType,
      sizeBytes: bytes.length,
    ),
  );
}
