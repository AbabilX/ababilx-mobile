import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/models/chat_conversation.dart';
import '../../messages/message_e2ee/encryption_pins.dart';
import '../../profile/providers/profile_provider.dart';
import 'attachment_secret.dart';

/// Whether an upload into [conversation] is encrypted on this phone first.
///
/// - [enabled] is `encrypted_attachments` on `/api/me`, or this phone's memory
///   of having been told so once (EncryptionPins.sealsUploads). Absent on a
///   server that predates 0168 and would store the ciphertext without its
///   key. Reading needs no flag.
/// - The conversation has to be one whose messages are sealed, because the
///   file's key travels sealed under the conversation key. A webhook feed
///   has none.
/// - A group the server marks `plaintext_until_keyed` may still fall back to
///   a plaintext send when somebody in it has no identity yet. An encrypted
///   file would then arrive with nowhere to put its key, so its uploads stay
///   as they are until the group is keyed.
/// - [pinned]: this phone has known the chat as encrypted. Its messages are
///   always sealed from then on, so its files are too, whatever the list
///   says about it now.
bool shouldSealUpload({
  required bool enabled,
  required ChatConversation? conversation,
  bool pinned = false,
}) {
  if (!enabled) return false;
  if (pinned) return true;
  return conversation != null && showsAsSealed(conversation);
}

/// A fresh key for an upload about to be presigned, or null when the file
/// goes up as it is.
Future<AttachmentSecret?> sealedUploadSecret(
  Ref ref,
  ChatConversation? conversation, {
  required String userId,
  required String conversationId,
  required String contentType,
  required String fileName,
  required int sizeBytes,
}) async {
  final pins = ref.read(encryptionPinsProvider);
  final enabled = await pins.sealsUploads(
    userId,
    enabled:
        ref.read(profileProvider).valueOrNull?.encryptedAttachments ?? false,
  );
  final pinned = await pins.isPinned(userId, conversationId);
  if (!shouldSealUpload(
    enabled: enabled,
    conversation: conversation,
    pinned: pinned,
  )) {
    return null;
  }
  return AttachmentSecret.forUpload(
    fileName: fileName,
    contentType: contentType,
    plainSize: sizeBytes,
  );
}
