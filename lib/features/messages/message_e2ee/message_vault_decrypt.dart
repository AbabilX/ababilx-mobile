part of 'message_vault.dart';

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
    final quote = message.quote;
    if (quote == null || !quote.isEncrypted) return null;
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

  Future<ChatMessage> decryptMessage(
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
      var key = await _loadKey(message.conversationId, currentUserId);
      // A newer key version means the other side rotated (usually after a PIN
      // reset), so the cached key is stale and worth one refetch.
      if (key != null && (message.encryptionKeyVersion ?? 0) > key.version) {
        key = await _loadKey(
          message.conversationId,
          currentUserId,
          refresh: true,
        );
      }
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
      return message.copyWith(body: utf8.decode(clear), quote: quote);
    } catch (_) {
      return message.copyWith(
        body: 'Unable to decrypt this message',
        quote: quote,
      );
    }
  }

  Future<List<ChatMessage>> decryptMessages(
    List<ChatMessage> messages,
    String currentUserId,
  ) => Future.wait(messages.map((m) => decryptMessage(m, currentUserId)));
}
