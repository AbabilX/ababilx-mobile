import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/crypto/attachment_file_cipher.dart';
import '../messages/data/models/chat_models.dart';
import '../messages/message_e2ee/message_vault.dart';
import '../messages/providers/chat_provider.dart';

/// Opens a timed photo its sender encrypted (server 0168).
///
/// The server withholds the photo's sealed key together with its URL and
/// hands both out when the receiver opens it ([grant]). What was downloaded
/// is ciphertext; this opens the key under the conversation key and then the
/// photo, all in memory. Null when the key does not open on this phone.
Future<Uint8List?> openSealedTimedPhoto(
  WidgetRef ref,
  ChatMessageAttachment attachment,
  TimedMediaGrant grant,
  Uint8List cipher,
) async {
  final state = ref.read(chatProvider);
  final conversationId = _conversationOf(state.feeds.values, attachment);
  if (conversationId == null || state.currentUserId.isEmpty) return null;
  final opened = await ref
      .read(messageVaultProvider)
      .openAttachment(
        conversationId: conversationId,
        currentUserId: state.currentUserId,
        attachment: ChatMessageAttachment(
          id: attachment.id,
          messageId: attachment.messageId,
          fileName: attachment.fileName,
          fileUrl: grant.url,
          contentType: attachment.contentType,
          sizeBytes: attachment.sizeBytes,
          uploadedBy: attachment.uploadedBy,
          createdAt: attachment.createdAt,
          encMeta: grant.encMeta,
          encNonce: grant.encNonce,
          encKeyVersion: grant.encKeyVersion,
        ),
      );
  final secret = opened.secret;
  if (secret == null) return null;
  return AttachmentFileCipher.openBytes(cipher, secret.key, secret.plainSize);
}

/// The conversation the photo's message is in. The key's seal names its
/// conversation, and an attachment does not carry one, so it is read off the
/// message this phone is showing.
String? _conversationOf(
  Iterable<ChatFeed> feeds,
  ChatMessageAttachment attachment,
) {
  for (final feed in feeds) {
    for (final message in feed.messages) {
      if (message.id == attachment.messageId) return message.conversationId;
    }
  }
  return null;
}
