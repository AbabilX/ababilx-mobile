import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';

Future<WallAttachmentInput?> pickWallImageAttachment(
  BuildContext context,
  WidgetRef ref, {
  required bool isPremium,
}) async {
  if (!isPremium) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachments require team premium')),
    );
    return null;
  }
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
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
