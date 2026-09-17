import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../shared/media/media_grid_sheet.dart';
import '../../../shared/media/media_quality.dart';
import '../../../shared/media/native_media_send.dart';
import '../../../shared/media/picked_media_file.dart';
import '../data/models/chat_models.dart';
import 'composer_upload.dart';

export 'composer_pending_previews.dart' show ComposerPendingPreviews;
export 'composer_upload_source.dart' show ChatAttachmentSizeException;

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
/// The gallery route opens the in-app picker rather than the system one: on
/// Android that is the native flow, which now opens on your **albums** — the
/// composer's "+" panel already shows a rail of recent media, so a Gallery
/// button that opened on a second copy of it reached nothing the rail did not.
/// Elsewhere the Dart grid sheet stands in, and when the library cannot be
/// read at all it reports [MediaSheetAction.files] so the system picker takes
/// over, which needs no permission of ours.
///
/// [onAdded] fires once per uploaded file, in the order they were chosen —
/// the uploads themselves run several at a time, see [uploadAttachments].
Future<ComposerAttachResult> pickAndUploadAttachment(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
  required ValueChanged<String> onFailed,
  UploadProgress? onProgress,
  ValueChanged<String>? onNativeSendReady,
  ImageSource? source,
  ComposerAttachKind? kind,
  CancelToken? cancelToken,
}) async {
  final requested = kind ?? _kindFor(source);

  // Android goes through the native picker + review + editor, whichever button
  // was pressed: a shot and a picked file get the same review screen the
  // gallery does, rather than being uploaded behind the user's back. Anything
  // else — iOS, or a build without the channel — keeps the Dart pickers.
  // Availability is asked first so backing out of the native screen ends the
  // attach rather than falling through to the old sheet.
  if (await NativeMediaSend.isAvailable()) {
    return _nativeAttach(
      ref,
      conversationId,
      requested,
      onAdded,
      onFailed,
      onProgress,
      onNativeSendReady,
      cancelToken,
    );
  }

  if (requested == ComposerAttachKind.camera) {
    await _settle();
    await _uploadPicked(
      ref,
      conversationId,
      await pickLiveCameraFile(),
      onAdded,
      onFailed,
      onProgress,
      cancelToken,
    );
    return const ComposerAttachResult();
  }
  if (requested == ComposerAttachKind.file) {
    await _settle();
    await _uploadPicked(
      ref,
      conversationId,
      await deviceFileSource()(),
      onAdded,
      onFailed,
      onProgress,
      cancelToken,
    );
    return const ComposerAttachResult();
  }
  if (!context.mounted) return const ComposerAttachResult();

  final result = await showMediaGridSheet(context);
  if (result == null) return const ComposerAttachResult();

  switch (result.action) {
    case MediaSheetAction.camera:
      await _settle();
      await _uploadPicked(
        ref,
        conversationId,
        await pickLiveCameraFile(),
        onAdded,
        onFailed,
        onProgress,
        cancelToken,
      );
    case MediaSheetAction.files:
      await _settle();
      await _uploadPicked(
        ref,
        conversationId,
        await deviceFileSource()(),
        onAdded,
        onFailed,
        onProgress,
        cancelToken,
      );
    case MediaSheetAction.picked:
      await uploadAttachments(
        ref,
        conversationId: conversationId,
        sources: result.items.map(libraryItemSource).toList(),
        onAdded: onAdded,
        onFailed: onFailed,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
  }
  return const ComposerAttachResult();
}

/// The native flow, opened at whichever door the pressed button names.
///
/// The level it was sent at comes back with the files: the review screen has
/// its own Media quality sheet, and a change made there is the user changing
/// the setting, so it is written straight back.
Future<ComposerAttachResult> _nativeAttach(
  WidgetRef ref,
  String conversationId,
  ComposerAttachKind kind,
  ValueChanged<ChatAttachmentInput> onAdded,
  ValueChanged<String> onFailed,
  UploadProgress? onProgress,
  ValueChanged<String>? onNativeSendReady,
  CancelToken? cancelToken,
) async {
  final native = await NativeMediaSend.open(
    start: switch (kind) {
      ComposerAttachKind.camera => NativeMediaStart.camera,
      ComposerAttachKind.file => NativeMediaStart.files,
      ComposerAttachKind.gallery => NativeMediaStart.gallery,
    },
    quality: ref.read(mediaQualityProvider),
  );
  if (native == null) return const ComposerAttachResult();
  await ref.read(mediaQualityProvider.notifier).set(native.quality);
  await uploadAttachments(
    ref,
    conversationId: conversationId,
    sources: native.files.map(nativeFileSource).toList(),
    onAdded: onAdded,
    onFailed: onFailed,
    onProgress: onProgress,
    cancelToken: cancelToken,
    onReady: onNativeSendReady == null
        ? null
        : () => onNativeSendReady(native.caption),
  );
  return onNativeSendReady == null
      ? ComposerAttachResult(sendRequested: true, caption: native.caption)
      : const ComposerAttachResult();
}

/// One file the pickers already read for us — a camera shot, a document.
Future<void> _uploadPicked(
  WidgetRef ref,
  String conversationId,
  Object? picked,
  ValueChanged<ChatAttachmentInput> onAdded,
  ValueChanged<String> onFailed,
  UploadProgress? onProgress,
  CancelToken? cancelToken,
) async {
  if (picked == null) return;
  await uploadAttachments(
    ref,
    conversationId: conversationId,
    sources: [
      if (picked is PickedMediaFile) pickedFileSource(picked),
      if (picked is UploadSource) () async => picked,
    ],
    onAdded: onAdded,
    onFailed: onFailed,
    onProgress: onProgress,
    cancelToken: cancelToken,
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

/// Backwards-compatible alias used by older call sites.
Future<ComposerAttachResult> pickAndUploadImage(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ValueChanged<ChatAttachmentInput> onAdded,
  required ValueChanged<String> onFailed,
  UploadProgress? onProgress,
  ValueChanged<String>? onNativeSendReady,
  ImageSource? source,
  ComposerAttachKind? kind,
  CancelToken? cancelToken,
}) => pickAndUploadAttachment(
  context,
  ref,
  conversationId: conversationId,
  onAdded: onAdded,
  onFailed: onFailed,
  onProgress: onProgress,
  onNativeSendReady: onNativeSendReady,
  source: source,
  kind: kind,
  cancelToken: cancelToken,
);
