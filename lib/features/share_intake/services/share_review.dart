import 'dart:io';

import '../../../shared/media/media_quality.dart';
import '../../../shared/media/native_media_send.dart';
import '../data/shared_payload.dart';

/// What the review screen made of a share.
class ShareReviewResult {
  const ShareReviewResult({
    required this.payload,
    required this.quality,
    this.cancelled = false,
  });

  final SharedPayload payload;
  final MediaQuality quality;

  /// The user backed out of the review screen. The share is untouched and the
  /// caller should drop it rather than quietly sending the originals.
  final bool cancelled;
}

/// Runs a share through the native review screen — the same one the composer
/// opens — so a photo arriving from another app can be cropped, drawn on and
/// sent at the chosen quality instead of going out exactly as received.
///
/// Only media is offered: a PDF has nothing to review. When there is none, or
/// the native flow is not there (iOS, or a build without the channel), the
/// payload is handed straight back and the share behaves as it always did.
///
/// The reviewed files come back as real paths, so they re-enter the payload as
/// `file://` URIs. `ShareIntakeBridge.materialize` reads through the content
/// resolver, which opens those exactly as it opens a `content://` one — so
/// nothing downstream of here has to know a review happened.
Future<ShareReviewResult> reviewSharedPayload(
  SharedPayload payload,
  MediaQuality quality,
) async {
  final media = payload.sendableFiles.where((f) => f.hasPreview).toList();
  if (media.isEmpty) {
    return ShareReviewResult(payload: payload, quality: quality);
  }
  if (!await NativeMediaSend.isAvailable()) {
    return ShareReviewResult(payload: payload, quality: quality);
  }

  final result = await NativeMediaSend.open(
    start: NativeMediaStart.review,
    quality: quality,
    maxSelection: media.length,
    inputs: [
      for (final file in media)
        NativeMediaInput(
          uri: file.uri,
          fileName: file.fileName,
          contentType: file.contentType,
        ),
    ],
  );
  if (result == null) {
    return ShareReviewResult(
      payload: payload,
      quality: quality,
      cancelled: true,
    );
  }

  // Anything that was not reviewable is kept in its original place in the
  // list, so a share of a photo and a PDF still sends both.
  final untouched = payload.files.where((f) => !f.hasPreview);
  return ShareReviewResult(
    payload: SharedPayload(
      files: [
        for (final file in result.files) _asSharedFile(file),
        ...untouched,
      ],
      text: result.caption.isEmpty ? payload.text : result.caption,
    ),
    quality: result.quality,
  );
}

SharedFile _asSharedFile(NativeMediaFile file) => SharedFile(
  uri: Uri.file(file.path).toString(),
  fileName: file.fileName,
  contentType: file.contentType,
  sizeBytes: file.sizeBytes > 0 ? file.sizeBytes : File(file.path).lengthSync(),
);
