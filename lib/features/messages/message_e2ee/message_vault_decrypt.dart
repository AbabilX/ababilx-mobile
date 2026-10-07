part of 'message_vault.dart';

/// A quote card shows a line or two; this is room to spare.
const _longQuotePreview = 240;

/// Reading sealed messages: the conversation key is resolved (and refetched
/// once when the other side rotated), then the ciphertext and any quoted
/// preview are opened under it.
extension MessageVaultDecrypt on MessageVault {
  /// Decrypts a quoted message's preview, if it has one and it is ciphertext.
  ///
  /// The quote is resolved by the server from the original row, so in a DM it
  /// arrives encrypted under the same conversation key — and under the
  /// *quoted* sender's id, which the cipher binds into its AAD. Running it back
  /// through [decryptMessage] as a stand-in message reuses the key cache and
  /// the rotation refetch; the stand-in carries no quote of its own, so this
  /// recurses exactly once.
  Future<ChatMessageQuote?> _decryptQuote(
    ChatMessage message,
    String currentUserId,
  ) async {
    var quote = message.quote;
    if (quote == null) {
      // A private-chat reply whose original the server no longer holds:
      // resolved from local history, and a plaintext one is already readable.
      final id = message.privateQuoteId;
      final lookup = privateQuoteLookup;
      if (id == null || lookup == null) return null;
      quote = await lookup(message.conversationId, id);
      if (quote == null || !quote.isEncrypted) return quote;
    } else if (quote.long) {
      return _longQuote(message, quote, currentUserId);
    } else if (!quote.isEncrypted) {
      return null;
    }
    final decrypted = await decryptMessage(
      ChatMessage(
        id: quote.messageId,
        conversationId: message.conversationId,
        userId: quote.userId,
        body: '',
        createdAt: '',
        encryptedBody: quote.encryptedBody,
        encryptionNonce: quote.encryptionNonce,
        encryptionVersion: 1,
        encryptionKeyVersion: quote.encryptionKeyVersion,
      ),
      currentUserId,
    );
    return quote.copyWith(body: decrypted.body);
  }

  /// A quote whose original the server left out for its size: read from this
  /// phone's own history, and kept as the short preview a quote card draws —
  /// never the whole text on every reply to it. Null (the card then says
  /// "Long message") when the original is not on this phone.
  Future<ChatMessageQuote?> _longQuote(
    ChatMessage message,
    ChatMessageQuote quote,
    String currentUserId,
  ) async {
    final lookup = privateQuoteLookup;
    if (lookup == null || quote.messageId.isEmpty) return null;
    final local = await lookup(message.conversationId, quote.messageId);
    if (local == null || local.deleted) return null;
    var body = local.body;
    if (local.isEncrypted) {
      final opened = await decryptMessage(
        ChatMessage(
          id: local.messageId,
          conversationId: message.conversationId,
          userId: local.userId,
          body: '',
          createdAt: '',
          encryptedBody: local.encryptedBody,
          encryptionNonce: local.encryptionNonce,
          encryptionVersion: 1,
          encryptionKeyVersion: local.encryptionKeyVersion,
        ),
        currentUserId,
      );
      if (isVaultFailureBody(opened.body)) return null;
      body = opened.body;
    }
    final preview = tiptapToPreviewText(body);
    // By rune: a cut inside a surrogate pair would tear an emoji in two.
    return quote.copyWith(
      body: preview.length > _longQuotePreview
          ? String.fromCharCodes(preview.runes.take(_longQuotePreview))
          : preview,
    );
  }

  /// Opens a message: its text, the preview of what it quotes, and the keys
  /// of its encrypted files (server 0168) — those open on their own, so a
  /// file whose key this account holds is readable even beside a body that
  /// is not, and the other way round.
  Future<ChatMessage> decryptMessage(
    ChatMessage message,
    String currentUserId,
  ) async => _openAttachments(
    await _decryptBody(message, currentUserId),
    currentUserId,
  );

  Future<ChatMessage> _decryptBody(
    ChatMessage message,
    String currentUserId,
  ) async {
    // An attachment-only DM carries no ciphertext of its own but can still
    // quote one, so the quote is resolved before the outer early-return.
    final quote = await _decryptQuote(message, currentUserId);
    if (!message.isEncrypted) {
      return quote == null ? message : message.copyWith(quote: quote);
    }
    if (!isUnlocked) {
      return message.copyWith(body: 'Encrypted message', quote: quote);
    }
    if (currentUserId.isEmpty) {
      return message.copyWith(body: 'Encrypted message', quote: quote);
    }
    try {
      final body = await _openSealedBody(message, currentUserId);
      return message.copyWith(body: body, quote: quote);
    } catch (_) {
      // A message no key opens may still have come back from a local backup,
      // which carries its text (features/local-backup, after "start fresh").
      final restored = await _restoredBody(message.id, currentUserId);
      return message.copyWith(
        body: restored ?? 'Unable to decrypt this message',
        quote: quote,
      );
    }
  }

  /// The ciphertext opened under its conversation key, or a throw — never a
  /// placeholder, so callers that must not keep one (the local backup) can
  /// tell a failure from a message.
  Future<String> _openSealedBody(
    ChatMessage message,
    String currentUserId,
  ) async {
    // Memory, then this device's own stored envelope, then the network — see
    // [MessageVaultKeyCache._readKey]. Reading starts on the device so a phone
    // with no connection reads its history rather than drawing "Unable to
    // decrypt this message" over messages it already holds.
    final key = await _readKey(
      message.conversationId,
      currentUserId,
      message.encryptionKeyVersion,
    );
    if (key == null || key.version != message.encryptionKeyVersion) {
      throw StateError('Secure message key is unavailable');
    }
    final clear = await _aes.decrypt(
      _box(message.encryptedBody!, message.encryptionNonce!),
      secretKey: key.key,
      aad: utf8.encode(
        'ababilx-dm-v1:${message.conversationId}:${key.version}:${message.userId}',
      ),
    );
    return utf8.decode(clear);
  }

  Future<String?> _restoredBody(String messageId, String userId) async {
    final lookup = restoredBodyLookup;
    if (lookup == null || messageId.isEmpty) return null;
    try {
      return await lookup(messageId, userId);
    } catch (_) {
      return null;
    }
  }

  Future<List<ChatMessage>> decryptMessages(
    List<ChatMessage> messages,
    String currentUserId,
  ) => Future.wait(messages.map((m) => decryptMessage(m, currentUserId)));
}
