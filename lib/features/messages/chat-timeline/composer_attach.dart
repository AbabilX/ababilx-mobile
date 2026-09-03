import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/media/device_gallery.dart';
import '../../../shared/media/media_grid_sheet.dart';
import '../../../shared/media/native_media_send.dart';
import '../../../shared/media/pick_single_media.dart';
import '../../../shared/media/picked_media_file.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'pending_preview_cache.dart';

export 'composer_pending_previews.dart' show ComposerPendingPreviews;

enum ComposerAttachKind { gallery, camera, file }

/// What the attach run decided.
///
/// The native flow ends on its own Send button, so it does not just hand back
/// attachments — it says "the user has finished, post this now", with the one
/// message they typed under the album. The Dart sheet leaves both false/empty
/// and the composer waits for the send button as it always has.
class ComposerAttachResult {
  const ComposerAttachResult({this.sendRequested = false, this.caption = ''});

  final bool sendRequested;
  final String caption;
}

/// Picks attachments and uploads them.
///
/// The gallery route opens the in-app grid (Signal's attachment keyboard)
/// rather than the system picker: the thumbnails come from a MediaStore cursor
/// so the sheet is populated as it opens, several items can be chosen at once,
/// and Camera and Files stay one tap away inside the same sheet. When the
/// library cannot be read the sheet reports [MediaSheetAction.files] and we
/// fall through to the system picker, which needs no permission of ours.
///
/// [onAdded] fires once per uploaded file, in the order they were chosen.
Future<ComposerAttachResult> pickAndUploadAttachment(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
  ImageSource? source,
  ComposerAttachKind? kind,
}) async {
  final requested = kind ?? _kindFor(source);

  if (requested == ComposerAttachKind.camera) {
    await _settle();
    await _uploadOne(ref, conversationId, await pickLiveCameraFile(), onAdded);
    return const ComposerAttachResult();
  }
  if (requested == ComposerAttachKind.file) {
    await _settle();
    await _uploadOne(ref, conversationId, await pickDeviceFile(), onAdded);
    return const ComposerAttachResult();
  }

  // Android goes through the native picker + review + editor. Anything else —
  // iOS, or a build without the channel — keeps the Dart sheet. Availability
  // is asked first so backing out of the native screen ends the attach rather
  // than falling through to the old sheet.
  if (await NativeMediaSend.isAvailable()) {
    final native = await NativeMediaSend.open();
    if (native == null) return const ComposerAttachResult();
    for (final file in native.files) {
      await _uploadNative(ref, conversationId, file, onAdded);
    }
    return ComposerAttachResult(sendRequested: true, caption: native.caption);
  }
  if (!context.mounted) return const ComposerAttachResult();

  final result = await showMediaGridSheet(context);
  if (result == null) return const ComposerAttachResult();

  switch (result.action) {
    case MediaSheetAction.camera:
      await _settle();
      await _uploadOne(
        ref,
        conversationId,
        await pickLiveCameraFile(),
        onAdded,
      );
    case MediaSheetAction.files:
      await _settle();
      await _uploadOne(ref, conversationId, await pickDeviceFile(), onAdded);
    case MediaSheetAction.picked:
      for (final item in result.items) {
        final file = await DeviceGallery.materialize(item);
        if (file == null) continue;
        final bytes = await file.readAsBytes();
        await _uploadOne(
          ref,
          conversationId,
          PickedMediaFile(
            bytes: bytes,
            fileName: item.name,
            contentType: item.mime,
          ),
          onAdded,
          localPath: file.path,
        );
      }
  }
  return const ComposerAttachResult();
}

/// A tap straight on the attachment keyboard's rail: one library item, no
/// picker in between. The bytes are materialised first because a
/// `content://` grant does not outlive the panel that handed it over.
Future<void> uploadDeviceMediaItem(
  WidgetRef ref, {
  required String conversationId,
  required DeviceMediaItem item,
  required ValueChanged<ChatAttachmentInput> onAdded,
}) async {
  final file = await DeviceGallery.materialize(item);
  if (file == null) return;
  final bytes = await file.readAsBytes();
  await _uploadOne(
    ref,
    conversationId,
    PickedMediaFile(bytes: bytes, fileName: item.name, contentType: item.mime),
    onAdded,
    localPath: file.path,
  );
}

/// The native flow already wrote a real file, edits flattened in.
Future<void> _uploadNative(
  WidgetRef ref,
  String conversationId,
  NativeMediaFile file,
  ValueChanged<ChatAttachmentInput> onAdded,
) async {
  final source = File(file.path);
  if (!await source.exists()) return;
  final bytes = await source.readAsBytes();
  await _uploadOne(
    ref,
    conversationId,
    PickedMediaFile(
      bytes: bytes,
      fileName: file.fileName,
      contentType: file.contentType,
    ),
    onAdded,
    localPath: file.path,
  );
}

/// The system camera and document pickers are separate Activities, and some
/// Android builds refuse to start one while a sheet is still animating shut.
/// The in-app grid needs no such wait — it is drawn by us.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 280));

ComposerAttachKind _kindFor(ImageSource? source) => switch (source) {
  ImageSource.camera => ComposerAttachKind.camera,
  _ => ComposerAttachKind.gallery,
};

/// Presign, PUT, hand back. A failed upload discards the object it reserved so
/// the conversation's storage is not charged for bytes nobody will ever see.
Future<void> _uploadOne(
  WidgetRef ref,
  String conversationId,
  PickedMediaFile? picked,
  ValueChanged<ChatAttachmentInput> onAdded, {
  String? localPath,
}) async {
  if (picked == null) return;
  final notifier = ref.read(chatProvider.notifier);
  final presign = await notifier.presignAttachment(
    conversationId,
    contentType: picked.contentType,
    fileName: picked.fileName,
    sizeBytes: picked.sizeBytes,
  );
  try {
    await notifier.uploadAttachmentBytes(
      presign,
      picked.bytes,
      picked.contentType,
    );
  } catch (_) {
    await notifier.discardUpload(conversationId, presign.publicUrl);
    rethrow;
  }
  if (localPath != null) {
    PendingPreviewCache.put(presign.publicUrl, localPath);
  } else {
    await _cacheBytesForPreview(presign.publicUrl, picked);
  }
  await _adopt(ref, presign.publicUrl, picked, localPath);
  onAdded(
    ChatAttachmentInput(
      fileUrl: presign.publicUrl,
      fileName: picked.fileName,
      contentType: picked.contentType,
      sizeBytes: picked.sizeBytes,
    ),
  );
}

/// The bytes we just uploaded are already on this device, so file them in the
/// attachment store under the URL they landed at. Without this the sender is
/// shown a download button for their own photo the moment the message renders.
Future<void> _adopt(
  WidgetRef ref,
  String fileUrl,
  PickedMediaFile picked,
  String? localPath,
) async {
  final adopter = ref.read(attachmentAdopterProvider);
  if (localPath != null && localPath.isNotEmpty) {
    await adopter.adoptFile(
      fileUrl: fileUrl,
      fileName: picked.fileName,
      contentType: picked.contentType,
      source: File(localPath),
    );
    return;
  }
  await adopter.adoptBytes(
    fileUrl: fileUrl,
    fileName: picked.fileName,
    contentType: picked.contentType,
    bytes: picked.bytes,
  );
}

/// Camera shots and files chosen through SAF arrive as bytes with no path we
/// can keep, so the strip gets a copy in the cache to draw from.
Future<void> _cacheBytesForPreview(String url, PickedMediaFile picked) async {
  if (!picked.contentType.toLowerCase().startsWith('image/')) return;
  final path = await writePreviewCopy(picked.fileName, picked.bytes);
  if (path != null) PendingPreviewCache.put(url, path);
}

/// Backwards-compatible alias used by older call sites.
Future<ComposerAttachResult> pickAndUploadImage(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
  ImageSource? source,
  ComposerAttachKind? kind,
}) => pickAndUploadAttachment(
  context,
  ref,
  conversationId: conversationId,
  onAdded: onAdded,
  source: source,
  kind: kind,
);
