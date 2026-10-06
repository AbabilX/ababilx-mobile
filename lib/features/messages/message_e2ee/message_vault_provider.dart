part of 'message_vault.dart';

final messageVaultProvider = Provider<MessageVault>(
  (ref) =>
      MessageVault(
          ref.watch(chatRepositoryProvider),
          const SecureStorage(FlutterSecureStorage()),
          ref.watch(chatKeyCacheProvider),
        )
        ..onHistoryReset = ((userId) => cleanNewChatHistory(ref, userId))
        ..privateQuoteLookup = ((conversationId, messageId) =>
            resolvePrivateQuote(
              ref.read(chatMessageStoreProvider),
              conversationId,
              messageId,
            ))
        ..restoredBodyLookup = ((messageId, userId) =>
            ref.read(restoredBodyStoreProvider).lookup(messageId, userId)),
);
