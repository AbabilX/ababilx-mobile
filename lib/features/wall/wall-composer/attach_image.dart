import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../messages/chat_icon.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';

Future<WallAttachmentInput?> pickWallImageAttachment(
  BuildContext context,
  WidgetRef ref, {
  required bool isPremium,
  ImageSource? source,
}) async {
  if (!isPremium) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachments require team premium')),
    );
    return null;
  }

  final pickedSource = source ??
      await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedCamera01),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedImage01),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
  if (pickedSource == null) return null;

  final file = await ImagePicker().pickImage(source: pickedSource);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final contentType = file.mimeType ?? 'image/jpeg';
  final n = ref.read(wallProvider.notifier);
  final presign = await n.presignAttachment(
    contentType: contentType,
    fileName: file.name,
    sizeBytes: bytes.length,
  );
  await n.uploadBytes(presign, bytes, contentType);
  return WallAttachmentInput(
    fileUrl: presign.publicUrl,
    fileName: file.name,
    contentType: contentType,
    sizeBytes: bytes.length,
  );
}
