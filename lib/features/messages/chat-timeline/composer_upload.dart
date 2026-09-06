import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/pick_single_media.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'composer_upload_source.dart';
import 'pending_preview_cache.dart';

export 'composer_upload_source.dart';

/// How many attachments are transferred at once.
///
/// Three fills a mobile uplink without opening a connection per photo on a
/// network that may only sustain a few, and without starving the websocket the
/// conversation itself runs on.
const int _uploadConcurrency = 3;

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
}) async {
  final reserved = <_Reserved>[];
  for (final load in sources) {
    final source = await load();
    if (source == null) continue;
    final slot = await _reserve(ref, conversationId, source);
    if (slot == null) continue;
    reserved.add(slot);
    onAdded(slot.input);
  }
  if (reserved.isEmpty) return;

  var next = 0;
  Future<void> lane() async {
    while (true) {
      final index = next;
      if (index >= reserved.length) return;
      next += 1;
      final slot = reserved[index];
      if (!await _transfer(ref, conversationId, slot)) {
        onFailed(slot.input.fileUrl);
      }
    }
  }

  final lanes = _uploadConcurrency < reserved.length
      ? _uploadConcurrency
      : reserved.length;
  await Future.wait(List.generate(lanes, (_) => lane()));
}

/// One presigned destination and the local file that will fill it.
class _Reserved {
  const _Reserved(this.presign, this.source, this.input);

  final ChatPresignResult presign;
  final UploadSource source;
  final ChatAttachmentInput input;
}

/// Claims a URL and gets the preview on screen. No bytes are read here.
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

/// Reads the file and PUTs it. A failure discards the object it reserved, so
/// the conversation's storage is not charged for bytes nobody will ever see.
Future<bool> _transfer(
  WidgetRef ref,
  String conversationId,
  _Reserved slot,
) async {
  final notifier = ref.read(chatProvider.notifier);
  final bytes = await slot.source.read();
  if (bytes == null) {
    await notifier.discardUpload(conversationId, slot.presign.publicUrl);
    return false;
  }
  try {
    await notifier.uploadAttachmentBytes(
      slot.presign,
      bytes,
      slot.source.contentType,
    );
  } catch (_) {
    await notifier.discardUpload(conversationId, slot.presign.publicUrl);
    return false;
  }
  if (slot.source.localPath == null) {
    await _cacheBytesForPreview(slot.presign.publicUrl, slot.source, bytes);
  }
  await _adopt(ref, slot, bytes);
  return true;
}

/// The bytes we just uploaded are already on this device, so file them in the
/// attachment store under the URL they landed at. Without this the sender is
/// shown a download button for their own photo the moment the message renders.
Future<void> _adopt(WidgetRef ref, _Reserved slot, Uint8List bytes) async {
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
