import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/providers/attachment_providers.dart';
import '../../privacy-mode/privacy_media.dart';
import '../chat-timeline/composer_reply_target.dart';
import '../data/models/chat_models.dart';
import '../group-member-permissions/group_media_guard.dart';
import '../providers/chat_provider.dart';
import '../tiptap_encode.dart';
import 'snippet_format.dart';

/// Uploads [content] as a `.md` / `.txt` file and posts it, with [message] as
/// the text beside it. Goes through the chat notifier's own upload methods, so
/// the file is encrypted wherever any other chat file is.
///
/// Throws when the file could not be reserved or uploaded, after discarding
/// the reserved object. Once the upload is in, a send that fails is the chat's
/// own failed bubble with its retry, like any other message: the object is
/// kept for that retry and nothing is thrown.
///
/// False when the sender backed out of the privacy-mode media sheet — a
/// snippet is a file, and waits for that sheet like any other.
Future<bool> sendSnippet(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required String? parentId,
  required String title,
  required SnippetKind kind,
  required String content,
  required String message,
}) async {
  final notifier = ref.read(chatProvider.notifier);
  final fileName = snippetFileName(title, kind);
  final bytes = utf8.encode(content);
  validateGroupMedia(ref, conversationId, kind.contentType, fileName);

  final presign = await notifier.presignAttachment(
    conversationId,
    contentType: kind.contentType,
    fileName: fileName,
    sizeBytes: bytes.length,
  );
  try {
    await notifier.uploadAttachmentBytes(presign, bytes, kind.contentType);
  } catch (_) {
    await notifier.discardUpload(conversationId, presign.publicUrl);
    rethrow;
  }
  // The sender already holds the text: file it under the uploaded URL so the
  // card draws at once instead of offering a download. A locked chat keeps
  // nothing on disk, and the adopter skips it. Best effort — a full disk must
  // not stop a file that is already uploaded from being sent.
  try {
    await ref
        .read(attachmentAdopterProvider)
        .adoptBytes(
          fileUrl: presign.publicUrl,
          fileName: fileName,
          contentType: kind.contentType,
          bytes: bytes,
        );
  } catch (_) {}
  if (!context.mounted) {
    await notifier.discardUpload(conversationId, presign.publicUrl);
    return false;
  }
  final files = await askPrivacyMediaRules(
    context,
    ref,
    ref.read(chatProvider).conversationById(conversationId),
    [
      ChatAttachmentInput(
        fileUrl: presign.publicUrl,
        fileName: fileName,
        contentType: kind.contentType,
        sizeBytes: bytes.length,
      ),
    ],
  );
  if (files == null) {
    await notifier.discardUpload(conversationId, presign.publicUrl);
    return false;
  }
  final reply = ComposerReplyTarget.resolve(
    replyTo: ref.read(chatProvider).replyToMessage,
    threadRootId: parentId,
  );
  final text = message.trim();
  // Cleared before the send, as the composer does: the pending bubble already
  // carries the quote, and a slow send must not leave the banner up.
  notifier.setReplyToMessage(null);
  // Not awaited: the pending bubble is in the timeline from this call on, and
  // it reports and retries a failed send itself.
  unawaited(
    notifier.sendMessage(
      conversationId: conversationId,
      body: text.isEmpty ? '' : encodeTiptapBody(plain: text),
      parentId: reply.parentId,
      quotedMessageId: reply.quotedMessageId,
      quotePreview: reply.preview,
      attachments: files,
    ),
  );
  return true;
}
