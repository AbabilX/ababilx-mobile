import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/media/picked_media_file.dart';
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

  final pickedSource =
      source ??
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

  final file = pickedSource == ImageSource.camera
      ? await pickLiveCameraFile()
      : await pickGalleryImageFile();
  if (file == null) return null;
  return uploadWallAttachment(ref, file);
}

Future<WallAttachmentInput?> pickWallFileAttachment(
  BuildContext context,
  WidgetRef ref, {
  required bool isPremium,
}) async {
  if (!_wallAttachmentsAllowed(context, isPremium)) return null;
  final file = await pickDeviceFile();
  if (file == null) return null;
  return uploadWallAttachment(ref, file);
}

Future<WallAttachmentInput> uploadWallAttachment(
  WidgetRef ref,
  PickedMediaFile file,
) async {
  final n = ref.read(wallProvider.notifier);
  final presign = await n.presignAttachment(
    contentType: file.contentType,
    fileName: file.fileName,
    sizeBytes: file.sizeBytes,
  );
  await n.uploadBytes(presign, file.bytes, file.contentType);
  return WallAttachmentInput(
    fileUrl: presign.publicUrl,
    fileName: file.fileName,
    contentType: file.contentType,
    sizeBytes: file.sizeBytes,
  );
}

bool _wallAttachmentsAllowed(BuildContext context, bool isPremium) {
  if (isPremium) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Attachments require team premium')),
  );
  return false;
}
