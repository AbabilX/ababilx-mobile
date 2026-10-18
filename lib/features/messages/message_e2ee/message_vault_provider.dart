part of 'message_vault.dart';

final messageVaultProvider = Provider<MessageVault>(
  (ref) =>
      MessageVault(
          ref.watch(chatRepositoryProvider),
          const SecureStorage(FlutterSecureStorage()),
          ref.watch(chatKeyCacheProvider),
        )
        ..onHistoryReset = ((userId) => cleanNewChatHistory(ref, userId))
        ..onKeyHeld = ((userId, conversationId) => unawaited(
          ref.read(encryptionPinsProvider).pin(userId, [conversationId]),
        ))
        ..onSealingTo = ((self, userId, publicJwk) =>
            watchSealedKey(ref, self, userId, publicJwk))
        ..privateQuoteLookup = ((conversationId, messageId) =>
            resolvePrivateQuote(
              ref.read(chatMessageStoreProvider),
              conversationId,
              messageId,
            ))
        ..restoredBodyLookup = ((messageId, userId) =>
            ref.read(restoredBodyStoreProvider).lookup(messageId, userId))
        ..restoredBodiesPresent = ((userId) =>
            ref.read(restoredBodyStoreProvider).present(userId)),
);
