import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/pick_single_media.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'composer_upload_source.dart';
import 'pending_preview_cache.dart';

export 'composer_upload_source.dart';

/// Three transfers fill a mobile uplink without starving the websocket.
const int _uploadConcurrency = 3;

typedef UploadProgress = void Function(String fileUrl, int sent, int total);

/// Attaches [sources] and reports each one **in the order picked**.
///
/// Two rules, and the first is the reason this function exists:
///
/// **A tile appears before its bytes are uploaded.** The file is on disk the
/// moment the picker closes, and its URL is settled by the presign, so waiting
/// out a PUT before drawing anything meant an album of ten photos on a slow
/// uplink left the composer empty for a minute — which reads as "picking
/// photos is slow" rather than "uploading is". [onAdded] therefore fires from
/// the reserve pass, and the caller must not send until [settle] has been
/// awaited: the object behind that URL does not exist yet.
///
/// **Order is the order tapped.** The reserve pass runs one at a time, so an
/// album keeps its order however the transfers interleave afterwards.
///
/// A file that fails is dropped through [onFailed] rather than taken as fatal
/// — one bad photo must not discard the nine that worked.
Future<void> uploadAttachments(
  WidgetRef ref, {
  required String conversationId,
  required List<UploadSourceLoader> sources,
  required ValueChanged<ChatAttachmentInput> onAdded,
  required ValueChanged<String> onFailed,
  UploadProgress? onProgress,
  VoidCallback? onReady,
  CancelToken? cancelToken,
}) async {
  final loaded = <UploadSource>[];
  for (final load in sources) {
    if (cancelToken?.isCancelled == true) return;
    final source = await load();
    if (source == null) continue;
    validateChatAttachmentSize(source.sizeBytes);
    loaded.add(source);
  }

  final reserved = <_Reserved>[];
  for (final source in loaded) {
    if (cancelToken?.isCancelled == true) return;
    final slot = await _reserve(ref, conversationId, source);
    if (slot == null) continue;
    reserved.add(slot);
    onAdded(slot.input);
  }
  if (reserved.isEmpty) return;
  onReady?.call();

  var next = 0;
  Future<void> lane() async {
    while (true) {
      if (cancelToken?.isCancelled == true) return;
      final index = next;
      if (index >= reserved.length) return;
      next += 1;
      final slot = reserved[index];
      if (!await _transfer(
        ref,
        conversationId,
        slot,
        onProgress: onProgress,
        cancelToken: cancelToken,
      )) {
        onFailed(slot.input.fileUrl);
      }
    }
  }

  final lanes = _uploadConcurrency < reserved.length
      ? _uploadConcurrency
      : reserved.length;
  await Future.wait(List.generate(lanes, (_) => lane()));
}

class _Reserved {
  const _Reserved(this.presign, this.source, this.input);

  final ChatPresignResult presign;
  final UploadSource source;
  final ChatAttachmentInput input;
}

Future<_Reserved?> _reserve(
  WidgetRef ref,
  String conversationId,
  UploadSource source,
) async {
  final ChatPresignResult presign;
  try {
    presign = await ref
        .read(chatProvider.notifier)
        .presignAttachment(
          conversationId,
          contentType: source.contentType,
          fileName: source.fileName,
          sizeBytes: source.sizeBytes,
        );
  } catch (_) {
    return null;
  }
  final localPath = source.localPath;
  if (localPath != null) PendingPreviewCache.put(presign.publicUrl, localPath);
  return _Reserved(
    presign,
    source,
    ChatAttachmentInput(
      fileUrl: presign.publicUrl,
      fileName: source.fileName,
      contentType: source.contentType,
      sizeBytes: source.sizeBytes,
    ),
  );
}

Future<bool> _transfer(
  WidgetRef ref,
  String conversationId,
  _Reserved slot, {
  UploadProgress? onProgress,
  CancelToken? cancelToken,
}) async {
  final notifier = ref.read(chatProvider.notifier);
  final sizeBytes = slot.source.sizeBytes;
  void report(int sent, int total) {
    // Dio stream PUTs often never fire a final 100% tick — without this the
    // bubble footer sticks around ~70% until the message API returns.
    final knownTotal = total > 0 ? total : sizeBytes;
    final clampedSent = sent < 0
        ? 0
        : (knownTotal > 0 && sent > knownTotal ? knownTotal : sent);
    onProgress?.call(slot.input.fileUrl, clampedSent, knownTotal);
  }

  Uint8List? bytes;
  try {
    if (cancelToken?.isCancelled == true) return false;
    final path = slot.source.localPath;
    if (path != null && path.isNotEmpty) {
      await notifier.uploadAttachmentFile(
        slot.presign,
        File(path),
        slot.source.contentType,
        sizeBytes,
        cancelToken: cancelToken,
        onProgress: report,
      );
    } else {
      bytes = await slot.source.read();
      if (bytes == null) throw const FileSystemException('File unavailable');
      await notifier.uploadAttachmentBytes(
        slot.presign,
        bytes,
        slot.source.contentType,
        cancelToken: cancelToken,
        onProgress: report,
      );
    }
  } catch (_) {
    await notifier.discardUpload(conversationId, slot.presign.publicUrl);
    return false;
  }
  report(sizeBytes, sizeBytes);
  if (slot.source.localPath == null && bytes != null) {
    await _cacheBytesForPreview(slot.presign.publicUrl, slot.source, bytes);
  }
  await _adopt(ref, slot, bytes);
  return true;
}

/// The bytes we just uploaded are already on this device, so file them in the
/// attachment store under the URL they landed at. Without this the sender is
/// shown a download button for their own photo the moment the message renders.
Future<void> _adopt(WidgetRef ref, _Reserved slot, Uint8List? bytes) async {
  final adopter = ref.read(attachmentAdopterProvider);
  final localPath = slot.source.localPath;
  if (localPath != null && localPath.isNotEmpty) {
    await adopter.adoptFile(
      fileUrl: slot.input.fileUrl,
      fileName: slot.input.fileName,
      contentType: slot.input.contentType,
      source: File(localPath),
    );
    return;
  }
  if (bytes == null) return;
  await adopter.adoptBytes(
    fileUrl: slot.input.fileUrl,
    fileName: slot.input.fileName,
    contentType: slot.input.contentType,
    bytes: bytes,
  );
}

/// Camera shots and files chosen through SAF arrive as bytes with no path we
/// can keep, so the strip gets a copy in the cache to draw from.
Future<void> _cacheBytesForPreview(
  String url,
  UploadSource source,
  Uint8List bytes,
) async {
  if (!source.contentType.toLowerCase().startsWith('image/')) return;
  final path = await writePreviewCopy(source.fileName, bytes);
  if (path != null) PendingPreviewCache.put(url, path);
}
