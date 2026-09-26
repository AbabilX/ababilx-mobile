import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/providers/attachment_providers.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/providers/chat_provider.dart';
import 'khaam_payload.dart';

/// Posts [payload] as an ordinary message — the same send path, encryption,
/// outbox and reconciliation as text. A send that fails leaves the bubble
/// failed and retryable with the same body.
///
/// A [photo] goes up first through the ordinary attachment presign and rides
/// as the message's one attachment, named by [khaamPhotoFileName] so the card
/// finds it. It is filed into this phone's attachment store at once, so the
/// sender never downloads their own memory back.
///
/// How a send ended.
enum KhaamSendResult {
  sent,

  /// The bubble is in the chat but failed; tapping it retries.
  pending,

  /// The photo never uploaded, so nothing is in the chat yet: stay on the
  /// compose screen and let them try again.
  photoFailed,
}

Future<KhaamSendResult> sendKhaam(
  WidgetRef ref, {
  required String conversationId,
  required KhaamPayload payload,
  Uint8List? photo,
}) async {
  final chat = ref.read(chatProvider.notifier);
  final attachments = <ChatAttachmentInput>[];
  var body = payload;
  if (photo != null) {
    final name = khaamPhotoFileName(payload.id);
    const type = 'image/jpeg';
    try {
      final presign = await chat.presignAttachment(
        conversationId,
        contentType: type,
        fileName: name,
        sizeBytes: photo.length,
      );
      try {
        await chat.uploadAttachmentBytes(presign, photo, type);
      } catch (_) {
        await _discard(chat, conversationId, presign.publicUrl);
        return KhaamSendResult.photoFailed;
      }
      await ref
          .read(attachmentAdopterProvider)
          .adoptBytes(
            fileUrl: presign.publicUrl,
            fileName: name,
            contentType: type,
            bytes: photo,
          );
      attachments.add(
        ChatAttachmentInput(
          fileUrl: presign.publicUrl,
          fileName: name,
          contentType: type,
          sizeBytes: photo.length,
        ),
      );
      body = KhaamPayload(
        id: payload.id,
        coverId: payload.coverId,
        message: payload.message,
        lang: payload.lang,
        photo: name,
      );
    } catch (_) {
      return KhaamSendResult.photoFailed;
    }
  }
  try {
    final sent = await chat.sendMessage(
      conversationId: conversationId,
      body: encodeKhaamBody(body),
      attachments: attachments,
    );
    return sent != null ? KhaamSendResult.sent : KhaamSendResult.pending;
  } catch (_) {
    return KhaamSendResult.pending;
  }
}

Future<void> _discard(
  ChatNotifier chat,
  String conversationId,
  String url,
) async {
  try {
    await chat.discardUpload(conversationId, url);
  } catch (_) {
    // Best effort — the sweeper cleans orphans.
  }
}
