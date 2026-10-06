import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/models/chat_conversation.dart';
import '../../profile/providers/profile_provider.dart';
import 'attachment_secret.dart';

/// Whether an upload into [conversation] is encrypted on this phone first.
///
/// - [enabled] is the server's rollout switch (`encrypted_attachments` on
///   `/api/me`). Reading an encrypted file needs no switch; sending one waits
///   until every phone that might receive it can open it.
/// - The conversation has to be one whose messages are sealed, because the
///   file's key travels sealed under the conversation key. A webhook feed
///   has none.
/// - A group the server marks `plaintext_until_keyed` may still fall back to
///   a plaintext send when somebody in it has no identity yet. An encrypted
///   file would then arrive with nowhere to put its key, so its uploads stay
///   as they are until the group is keyed.
bool shouldSealUpload({
  required bool enabled,
  required ChatConversation? conversation,
}) {
  if (!enabled || conversation == null) return false;
  return conversation.isEncrypted && !conversation.plaintextUntilKeyed;
}

/// A fresh key for an upload about to be presigned, or null when the file
/// goes up as it is.
AttachmentSecret? sealedUploadSecret(
  Ref ref,
  ChatConversation? conversation, {
  required String contentType,
  required String fileName,
  required int sizeBytes,
}) {
  final enabled =
      ref.read(profileProvider).valueOrNull?.encryptedAttachments ?? false;
  if (!shouldSealUpload(enabled: enabled, conversation: conversation)) {
    return null;
  }
  return AttachmentSecret.forUpload(
    fileName: fileName,
    contentType: contentType,
    plainSize: sizeBytes,
  );
}
