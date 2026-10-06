import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/pick_image_bytes.dart';
import '../providers/chat_provider.dart';

/// Which picture is being set. A group has two, and they are cropped, uploaded
/// and saved identically — only the shape and the field differ.
enum GroupImageKind { photo, banner }

extension GroupImageKindX on GroupImageKind {
  CropShape get shape =>
      this == GroupImageKind.photo ? CropShape.circle : CropShape.wide;

  /// A banner is drawn full-bleed across a phone, so it needs the pixels; a
  /// photo is never larger than a 96px circle, and 512 already covers a 3x
  /// screen with room to spare.
  int get outputWidth => this == GroupImageKind.photo ? 512 : 1280;

  String get label => this == GroupImageKind.photo ? 'photo' : 'banner';

  String get fileName =>
      this == GroupImageKind.photo ? 'group-photo.jpg' : 'group-banner.jpg';
}

/// Pick a picture and frame it. Returns the cropped JPEG, or null if the user
/// backed out of either step.
///
/// Picking is kept apart from [uploadGroupImage] so the caller can show its
/// progress and its errors in its own surface. The flow runs from inside a
/// modal bottom sheet, and a SnackBar there is drawn behind the sheet — which
/// made a failed upload completely silent, indistinguishable from a successful
/// one that simply had not refreshed yet.
Future<Uint8List?> pickGroupImage(
  BuildContext context,
  GroupImageKind kind,
) async {
  final bytes = await pickImageBytes(context, title: 'Choose a ${kind.label}');
  if (bytes == null || !context.mounted) return null;

  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => ImageCropEditor(
        bytes: bytes,
        shape: kind.shape,
        outputWidth: kind.outputWidth,
      ),
    ),
  );
}

/// Uploads the cropped image and saves the URL onto the group. Throws on
/// failure so the caller can say so where the user is actually looking.
///
/// The bytes go up through the ordinary chat attachment presign, so the object
/// lands under this conversation's own storage prefix. That is exactly what the
/// server checks before it accepts the URL: an image from anywhere else is
/// refused, because every member's client fetches it on sight and an arbitrary
/// URL would be an IP-address beacon aimed at the whole group.
Future<void> uploadGroupImage(
  WidgetRef ref,
  String conversationId,
  Uint8List bytes,
  GroupImageKind kind,
) async {
  final chat = ref.read(chatProvider.notifier);
  final presign = await chat.presignAttachment(
    conversationId,
    contentType: 'image/jpeg',
    fileName: kind.fileName,
    sizeBytes: bytes.length,
    // The group's picture is stored on the conversation row and drawn by URL
    // on every client, so it is never encrypted like a message attachment.
    plain: true,
  );
  try {
    await chat.uploadAttachmentBytes(presign, bytes, 'image/jpeg');
    await chat.updateGroupInfo(
      conversationId,
      avatarUrl: kind == GroupImageKind.photo ? presign.publicUrl : null,
      bannerUrl: kind == GroupImageKind.banner ? presign.publicUrl : null,
    );
  } catch (error) {
    // An object nobody will ever reference is still billed and still readable.
    // Best effort: if the discard fails too, the retention sweep gets it.
    try {
      await chat.discardUpload(conversationId, presign.publicUrl);
    } catch (_) {}
    rethrow;
  }
}
