part of 'message_vault.dart';

/// Encrypted chat files (server migration 0168).
///
/// The file itself is sealed on the device under a random key of its own
/// (`AttachmentFileCipher`). What crosses the API is that key, with the real
/// file name, type and size, sealed here under the CONVERSATION key — the
/// same key, and the same key version, as the message body it travels with.
/// The server stores the result beside the attachment row and can open none
/// of it.
///
/// The AAD ([attachmentSealAad]) names the conversation, the key version and
/// whoever sealed it, as a message body's does, under its own prefix. It must
/// stay byte-identical on every client; pinned by
/// `test/features/messages/attachment_seal_test.dart`.
extension MessageVaultAttachments on MessageVault {
  /// Seals the key of every encrypted upload in [attachments] under the
  /// conversation key at [keyVersion] — the version the message body was just
  /// sealed with, so one key opens both. Keyed by file URL.
  ///
  /// Called again after a re-key: the previous seals name a version somebody
  /// in the conversation can no longer read.
  Future<Map<String, SealedAttachmentMeta>> sealAttachments({
    required String conversationId,
    required String currentUserId,
    required int keyVersion,
    required List<ChatAttachmentInput> attachments,
  }) async {
    final sealed = <String, SealedAttachmentMeta>{};
    if (!attachments.any((a) => a.secret != null)) return sealed;
    final key = await _readKey(conversationId, currentUserId, keyVersion);
    if (key == null || key.version != keyVersion) {
      throw StateError('Secure message key is unavailable');
    }
    for (final attachment in attachments) {
      final secret = attachment.secret;
      if (secret == null) continue;
      final nonce = _random(12);
      final box = await _aes.encrypt(
        AttachmentSealPayload(
          key: secret.key,
          fileName: attachment.fileName,
          contentType: attachment.contentType,
          plainSize: secret.plainSize,
        ).encode(),
        secretKey: key.key,
        nonce: nonce,
        aad: attachmentSealAad(conversationId, key.version, currentUserId),
      );
      sealed[attachment.fileUrl] = SealedAttachmentMeta(
        encMeta: _b64(_boxBytes(box)),
        encNonce: _b64(nonce),
      );
    }
    return sealed;
  }

  /// Opens one encrypted attachment's key, giving it back with its real
  /// name, type and size. Returned unchanged when there is nothing to open or
  /// no key that opens it — a locked vault, a key version this account does
  /// not hold — so the caller draws it as a file that is not available yet
  /// rather than failing the message around it.
  ///
  /// [sealerId] is who wrote the row: the message's sender, which is also the
  /// attachment's `uploaded_by`.
  Future<ChatMessageAttachment> openAttachment({
    required String conversationId,
    required String currentUserId,
    required ChatMessageAttachment attachment,
    String? sealerId,
    bool localOnly = false,
  }) async {
    if (!attachment.needsKey || !isUnlocked || currentUserId.isEmpty) {
      return attachment;
    }
    final sealer = sealerId ?? attachment.uploadedBy;
    try {
      final key = localOnly
          ? await _localReadKey(
              conversationId,
              currentUserId,
              attachment.encKeyVersion,
            )
          : await _readKey(
              conversationId,
              currentUserId,
              attachment.encKeyVersion,
            );
      if (key == null || key.version != attachment.encKeyVersion) {
        return attachment;
      }
      final clear = await _aes.decrypt(
        _box(attachment.encMeta, attachment.encNonce),
        secretKey: key.key,
        aad: attachmentSealAad(conversationId, key.version, sealer),
      );
      return attachment.opened(AttachmentSealPayload.decode(clear));
    } catch (_) {
      return attachment;
    }
  }

  /// [message] with every encrypted attachment opened that can be.
  Future<ChatMessage> _openAttachments(
    ChatMessage message,
    String currentUserId, {
    bool localOnly = false,
  }) async {
    if (!message.attachments.any((a) => a.needsKey)) return message;
    final opened = await Future.wait(
      message.attachments.map(
        (a) => openAttachment(
          conversationId: message.conversationId,
          currentUserId: currentUserId,
          attachment: a,
          sealerId: message.userId.isEmpty ? null : message.userId,
          localOnly: localOnly,
        ),
      ),
    );
    return message.copyWith(attachments: opened);
  }
}
