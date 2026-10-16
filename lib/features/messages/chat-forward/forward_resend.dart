import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/data/models/attachment_url_key.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../chat-details/group_permissions.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Whether a forward failed because the server no longer holds the source:
/// a held message (delivery-only, server 0173) leaves once every phone has
/// it, and the forward endpoint copies a server row, so it answers 404.
bool sourceLeftServer(Object error, ChatMessage message) =>
    message.heldForPhones &&
    error is DioException &&
    error.response?.statusCode == 404;

/// Forwards [message] from this phone's own copy: a new message from the
/// forwarder in each of [conversations], its text sealed by the ordinary send
/// and each file uploaded again from the local store into that chat. Returns
/// how many destinations took it.
///
/// It is a fresh send, not a server copy, so it carries no "Forwarded"
/// banner. A file this phone does not hold stops the whole forward — sending
/// the text without it would read as the full message.
Future<int> resendForward(
  ProviderContainer container,
  ChatMessage message,
  List<ChatConversation> conversations,
) async {
  final reason = resendRefusal(
    message,
    source: container
        .read(chatProvider)
        .conversationById(message.conversationId),
    currentUserId: container.read(chatProvider).currentUserId,
  );
  if (reason != null) throw StateError(reason);
  final notifier = container.read(chatProvider.notifier);
  final blobs = container.read(attachmentBlobStoreProvider);
  final files = <(ChatMessageAttachment, File)>[];
  for (final a in message.attachments) {
    final row = await blobs.read(attachmentUrlKey(a.fileUrl));
    final path = row?.localPath ?? '';
    final file = File(path);
    if (path.isEmpty || !await file.exists()) {
      throw StateError('This file is not on this phone any more.');
    }
    files.add((a, file));
  }
  var delivered = 0;
  for (final conversation in conversations) {
    final inputs = <ChatAttachmentInput>[];
    for (final (a, file) in files) {
      final size = await file.length();
      final presign = await notifier.presignAttachment(
        conversation.id,
        contentType: a.contentType,
        fileName: a.fileName,
        sizeBytes: size,
      );
      await notifier.uploadAttachmentFile(presign, file, a.contentType, size);
      inputs.add(
        ChatAttachmentInput(
          fileUrl: presign.publicUrl,
          fileName: a.fileName,
          contentType: a.contentType,
          sizeBytes: size,
        ),
      );
    }
    final sent = await notifier.sendMessage(
      conversationId: conversation.id,
      body: message.body,
      attachments: inputs,
    );
    if (sent != null && !sent.isPending) delivered++;
  }
  return delivered;
}

/// Why [message] may not be re-sent as a forward, or null. The server checks
/// these on an ordinary forward (`ForwardChatMessage`); it cannot check a
/// re-send, which reaches it as a new message, so the phone does: a timed
/// photo goes nowhere, somebody else's protected media stays with its
/// sender, and a private chat, a private group or a member barred from
/// forwarding forwards nothing out.
String? resendRefusal(
  ChatMessage message, {
  required ChatConversation? source,
  required String currentUserId,
}) {
  const refused = 'This message cannot be forwarded.';
  if (message.privateChat) return refused;
  if (message.attachments.any((a) => a.timed)) return refused;
  if (message.userId != currentUserId && message.hasProtectedMedia) {
    return refused;
  }
  if (source == null) return null;
  if (source.groupPrivacy || source.privateChat) return refused;
  if (!GroupPermissions(source).canForward) return refused;
  return null;
}
